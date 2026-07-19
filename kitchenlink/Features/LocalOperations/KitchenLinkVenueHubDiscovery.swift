import Foundation
import KitchenLinkLocalGuestCore
import Network

enum KitchenLinkVenueHubDiscoveryEvent: Equatable, Sendable {
    case hubs([KitchenLinkVenueHubBonjourDescriptor])
    case failed(String)
}

protocol KitchenLinkVenueHubDiscovering: AnyObject {
    var events: AsyncStream<KitchenLinkVenueHubDiscoveryEvent> { get }
    func start()
    func stop()
}

final class KitchenLinkBonjourVenueHubDiscovery: KitchenLinkVenueHubDiscovering, @unchecked Sendable {
    private let queue = DispatchQueue(label: "sf.kitchenlink.venue-hub-discovery")
    private let eventContinuation: AsyncStream<KitchenLinkVenueHubDiscoveryEvent>.Continuation
    let events: AsyncStream<KitchenLinkVenueHubDiscoveryEvent>
    private var browser: NWBrowser?
    private var currentHubs: [KitchenLinkVenueHubBonjourDescriptor] = []

    init() {
        let eventStream = AsyncStream.makeStream(
            of: KitchenLinkVenueHubDiscoveryEvent.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        events = eventStream.stream
        eventContinuation = eventStream.continuation
    }

    func start() {
        queue.async { [weak self] in
            guard let self, self.browser == nil else { return }
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            let browser = NWBrowser(
                for: .bonjourWithTXTRecord(
                    type: KitchenLinkVenueHubBonjourContract.serviceType,
                    domain: nil
                ),
                using: parameters
            )
            self.browser = browser
            browser.stateUpdateHandler = { [weak self] state in
                self?.handle(state)
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                self?.publish(results)
            }
            browser.start(queue: self.queue)
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.browser?.cancel()
            self.browser = nil
            self.currentHubs = []
            self.eventContinuation.finish()
        }
    }

    private func handle(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            eventContinuation.yield(.hubs(currentHubs))
        case .failed(let error):
            browser?.cancel()
            browser = nil
            eventContinuation.yield(
                .failed("Lokale Hub-Suche fehlgeschlagen: \(error.localizedDescription)")
            )
            eventContinuation.finish()
        case .cancelled:
            browser = nil
        case .setup, .waiting:
            break
        @unknown default:
            break
        }
    }

    private func publish(_ results: Set<NWBrowser.Result>) {
        currentHubs = results.compactMap { result in
            guard case .service(let name, _, _, _) = result.endpoint,
                  case .bonjour(let record) = result.metadata else {
                return nil
            }
            return KitchenLinkVenueHubBonjourContract.descriptor(
                serviceName: name,
                record: record.dictionary
            )
        }
        eventContinuation.yield(.hubs(currentHubs))
    }
}

@MainActor
final class KitchenLinkVenueHubDiscoveryModel: ObservableObject {
    enum State: Equatable {
        case stopped
        case searching
        case active
        case failed(String)
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var hubs: [KitchenLinkVenueHubBonjourDescriptor] = []

    private let localHubID: String
    private let discoveryFactory: () -> any KitchenLinkVenueHubDiscovering
    private var discovery: (any KitchenLinkVenueHubDiscovering)?
    private var eventTask: Task<Void, Never>?

    init() {
        localHubID = KitchenLinkVenueHubIdentity.deviceID()
        discoveryFactory = { KitchenLinkBonjourVenueHubDiscovery() }
    }

    init(
        localHubID: String,
        discoveryFactory: @escaping () -> any KitchenLinkVenueHubDiscovering
    ) {
        self.localHubID = localHubID
        self.discoveryFactory = discoveryFactory
    }

    var isSearching: Bool { state == .searching }

    var statusDetail: String {
        switch state {
        case .stopped:
            return "Lokale Hub-Suche ist gestoppt."
        case .searching:
            return "KitchenLink-Hubs im WLAN werden gesucht …"
        case .active where hubs.isEmpty:
            return "Keine anderen KitchenLink-Hubs im WLAN gefunden."
        case .active:
            return hubs.count == 1
                ? "Ein anderer KitchenLink-Hub wurde gefunden."
                : "\(hubs.count) andere KitchenLink-Hubs wurden gefunden."
        case .failed(let message):
            return message
        }
    }

    func start() {
        stop()
        state = .searching
        let discovery = discoveryFactory()
        self.discovery = discovery
        eventTask = Task { [weak self] in
            for await event in discovery.events {
                guard !Task.isCancelled, let self else { return }
                switch event {
                case .hubs(let hubs):
                    self.apply(hubs)
                case .failed(let message):
                    self.discovery = nil
                    self.hubs = []
                    self.state = .failed(message)
                    return
                }
            }
        }
        discovery.start()
    }

    func stop() {
        eventTask?.cancel()
        eventTask = nil
        discovery?.stop()
        discovery = nil
        hubs = []
        state = .stopped
    }

    private func apply(_ discoveredHubs: [KitchenLinkVenueHubBonjourDescriptor]) {
        var unique: [String: KitchenLinkVenueHubBonjourDescriptor] = [:]
        for hub in discoveredHubs where hub.hubID != localHubID {
            unique[hub.hubID] = hub
        }
        hubs = unique.values.sorted {
            if $0.name == $1.name {
                return $0.baseURL.absoluteString < $1.baseURL.absoluteString
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        state = .active
    }
}
