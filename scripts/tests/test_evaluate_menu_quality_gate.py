import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "evaluate-menu-quality-gate.py"
SPEC = importlib.util.spec_from_file_location("quality_gate", SCRIPT)
quality_gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(quality_gate)


def evidence(text, page=0):
    return {
        "rawText": text,
        "pageIndex": page,
        "boundingBox": {"x": 0.1, "y": 0.1, "width": 0.2, "height": 0.1},
        "method": "model",
        "confidence": 0.8,
        "reviewState": "needsReview",
        "isLocated": True,
    }


def text(value, page=0):
    return {
        "value": value,
        "languageTag": "de",
        "evidence": evidence(value, page),
        "alternatives": [],
    }


class MenuQualityGateTests(unittest.TestCase):
    def test_selected_pilot_projects_pages_in_report_order(self):
        manifest = {
            "schemaVersion": "kitchenlink-menu-quality-gate-manifest/1.0.0",
            "documents": [
                {
                    "fixtureID": "first",
                    "pages": [
                        {
                            "pageIndex": 2,
                            "pageKind": "menu",
                            "resourcePath": "first.png",
                        }
                    ],
                },
                {
                    "fixtureID": "second",
                    "pages": [
                        {
                            "pageIndex": 0,
                            "pageKind": "cover",
                            "resourcePath": "second.png",
                        }
                    ],
                },
            ],
        }
        truth = {
            "first": {
                "fixtureID": "first",
                "languageTag": "de-DE",
                "currencyCode": "EUR",
                "sections": [{"pageIndex": 2, "title": "Dessert"}],
                "entries": [{
                    "pageIndex": 2,
                    "section": "Dessert",
                    "name": "Sorbet",
                }],
                "notices": [],
                "documentDeclarations": [{"kind": "notice", "rawText": "global"}],
                "forbiddenEntryTexts": ["Logo"],
            },
            "second": {
                "fixtureID": "second",
                "languageTag": "de-DE",
                "currencyCode": "EUR",
                "sections": [],
                "entries": [],
                "notices": [],
                "documentDeclarations": [],
                "forbiddenEntryTexts": ["Slogan"],
            },
        }

        pilot_manifest, pilot_truths = quality_gate.build_selected_pilot_gate(
            manifest,
            truth,
            ["second:0", "first:2"],
        )
        pilot_truth = pilot_truths["pilot-selection"]

        self.assertEqual(pilot_manifest["selectedPageCount"], 2)
        self.assertEqual(
            [page["pageKind"] for page in pilot_manifest["documents"][0]["pages"]],
            ["cover", "menu"],
        )
        self.assertEqual(pilot_truth["entries"][0]["pageIndex"], 1)
        self.assertEqual(pilot_truth["sections"][0]["pageIndex"], 1)
        self.assertEqual(pilot_truth["documentDeclarations"], [])
        self.assertEqual(pilot_truth["forbiddenEntryTexts"], ["Slogan", "Logo"])

    def test_perfect_minimal_draft_scores_without_safety_errors(self):
        manifest = {
            "fixtureID": "fixture",
            "pages": [{"pageIndex": 0, "pageKind": "menu"}],
        }
        truth = {
            "currencyCode": "EUR",
            "sections": [{"pageIndex": 0, "title": "Dessert"}],
            "entries": [{
                "pageIndex": 0,
                "section": "Dessert",
                "name": "Sorbet",
                "kind": "food",
                "description": "Zitrone",
                "offers": [{
                    "priceKind": "fixed",
                    "amountCents": 700,
                    "rawPrice": "7,00 €",
                    "basis": "per_item",
                }],
                "declarationCodes": [],
            }],
            "documentDeclarations": [],
        }
        draft = {
            "sections": [{
                "title": text("Dessert"),
                "entries": [{
                    "name": text("Sorbet"),
                    "description": {
                        **text("Zitrone"),
                    },
                    "kind": "food",
                    "offers": [{
                        "priceKind": "fixed",
                        "amountCents": 700,
                        "deltaCents": None,
                        "minimumAmountCents": None,
                        "maximumAmountCents": None,
                        "currencyCode": "EUR",
                        "rawPrice": "7,00 €",
                        "basis": "per_item",
                        "evidence": evidence("7,00 €"),
                    }],
                    "quantities": [],
                    "optionGroups": [],
                    "bundleComponents": [],
                    "declarations": [],
                }],
                "subsections": [],
            }],
            "declarations": [],
            "reviewFindings": [],
            "processing": {
                "pageOutcomes": [{
                    "pageIndex": 0,
                    "status": "processed",
                    "attempts": 1,
                    "latencyMilliseconds": 125,
                }]
            },
        }
        snapshot = {"draft": draft, "draftValidationErrors": []}

        result = quality_gate.score_document(
            manifest, truth, snapshot, mode="local"
        )

        self.assertEqual(result["entryCounts"]["f1"], 1)
        self.assertEqual(result["offerCounts"]["f1"], 1)
        self.assertEqual(result["evidence"]["coverage"], 1)
        self.assertEqual(result["safety"]["inventedItems"], 0)
        self.assertEqual(result["safety"]["inventedPrices"], 0)
        self.assertEqual(result["operational"]["latencyCoverage"], 1)
        self.assertEqual(result["operational"]["pageFailureRate"], 0)

        metrics = quality_gate.aggregate_results([result])
        metrics["operational"]["repeatability"] = {
            "repeatRuns": 3,
            "exactSemanticRepeatability": 1,
        }
        policy = {
            "measurementTargets": {
                key: 1
                for key in (
                    "sectionF1",
                    "entryF1",
                    "nameExactAccuracy",
                    "categoryAssignmentAccuracy",
                    "descriptionF1",
                    "descriptionExactAccuracy",
                    "offerF1",
                    "priceTextExactAccuracy",
                    "priceBasisAccuracy",
                    "currencyAccuracy",
                    "relationF1",
                    "declarationF1",
                    "noticeF1",
                    "translationF1",
                    "evidenceCoverage",
                    "evidenceSupportAccuracy",
                    "groundTruthEvidenceAccuracy",
                    "expectedReviewRecall",
                )
            },
            "hardSafetyGates": {
                "maximumMissingItems": 0,
                "maximumInventedItems": 0,
                "maximumInventedPrices": 0,
                "maximumForbiddenClaimHits": 0,
                "maximumCoverFalsePositives": 0,
                "maximumSilentPageLosses": 0,
                "maximumValidationErrors": 0,
            },
            "operationalTargets": {
                "minimumLatencyCoverage": 1,
                "maximumP95PageLatencyMilliseconds": 1000,
                "maximumPageFailureRate": 0,
                "minimumRepeatRuns": 3,
                "minimumExactSemanticRepeatability": 1,
            },
        }

        self.assertEqual(
            quality_gate.enforcement_failures(metrics, policy),
            [],
        )

    def test_visible_notice_and_translation_are_scored_with_evidence(self):
        manifest = {
            "fixtureID": "notice",
            "pages": [{"pageIndex": 0, "pageKind": "information"}],
        }
        truth = {
            "sections": [],
            "entries": [],
            "documentDeclarations": [],
            "notices": [{
                "pageIndex": 0,
                "rawText": "Bitte wählen Sie eine Beilage",
                "translations": ["Please choose a side dish"],
            }],
        }
        draft = {
            "sections": [],
            "declarations": [{
                "kind": "notice",
                "rawText": "Bitte wählen Sie eine Beilage",
                "alternatives": [{
                    "value": "Please choose a side dish",
                    "languageTag": "en",
                    "evidence": evidence("Please choose a side dish"),
                }],
                "claim": "unknown",
                "scope": "document",
                "evidence": evidence("Bitte wählen Sie eine Beilage"),
            }],
            "processing": {
                "pageOutcomes": [{
                    "pageIndex": 0,
                    "status": "processed",
                    "attempts": 1,
                    "latencyMilliseconds": 100,
                }]
            },
        }

        result = quality_gate.score_document(
            manifest,
            truth,
            {"draft": draft, "draftValidationErrors": []},
            mode="local",
        )
        metrics = quality_gate.aggregate_results([result])

        self.assertEqual(result["noticeCounts"]["f1"], 1)
        self.assertEqual(metrics["noticeF1"], 1)
        self.assertEqual(metrics["translationF1"], 1)
        self.assertEqual(result["groundTruthEvidence"]["accuracy"], 1)

    def test_cover_item_is_a_hard_safety_signal(self):
        manifest = {
            "fixtureID": "cover",
            "pages": [{"pageIndex": 0, "pageKind": "cover"}],
        }
        truth = {
            "sections": [],
            "entries": [],
            "documentDeclarations": [],
        }
        draft = {
            "sections": [{
                "title": text("Logo"),
                "entries": [{
                    "name": text("Marketing slogan"),
                    "offers": [],
                    "optionGroups": [],
                    "bundleComponents": [],
                    "declarations": [],
                }],
                "subsections": [],
            }],
            "processing": {
                "pageOutcomes": [{
                    "pageIndex": 0,
                    "status": "empty",
                    "attempts": 1,
                }]
            },
        }

        result = quality_gate.score_document(
            manifest,
            truth,
            {"draft": draft, "draftValidationErrors": []},
            mode="local",
        )

        self.assertEqual(result["safety"]["coverFalsePositives"], 1)
        self.assertEqual(result["safety"]["inventedItems"], 1)

    def test_missing_item_is_a_hard_safety_failure(self):
        manifest = {
            "fixtureID": "fixture",
            "pages": [{"pageIndex": 0, "pageKind": "menu"}],
        }
        truth = {
            "sections": [{"pageIndex": 0, "title": "Dessert"}],
            "entries": [{
                "pageIndex": 0,
                "section": "Dessert",
                "name": "Sorbet",
                "offers": [],
                "declarationCodes": [],
            }],
            "documentDeclarations": [],
        }
        draft = {
            "sections": [],
            "declarations": [],
            "processing": {
                "pageOutcomes": [{
                    "pageIndex": 0,
                    "status": "processed",
                    "attempts": 1,
                    "latencyMilliseconds": 100,
                }]
            },
        }
        result = quality_gate.score_document(
            manifest,
            truth,
            {"draft": draft, "draftValidationErrors": []},
            mode="local",
        )
        metrics = quality_gate.aggregate_results([result])

        failures = quality_gate.enforcement_failures(
            metrics,
            {"hardSafetyGates": {"maximumMissingItems": 0}},
        )

        self.assertEqual(result["safety"]["missingItems"], 1)
        self.assertTrue(any("missingItems" in failure for failure in failures))

    def test_included_offer_without_raw_price_can_match_exactly(self):
        manifest = {
            "fixtureID": "fixture",
            "pages": [{"pageIndex": 0, "pageKind": "menu"}],
        }
        truth = {
            "currencyCode": "EUR",
            "sections": [{"pageIndex": 0, "title": "Menü"}],
            "entries": [{
                "pageIndex": 0,
                "section": "Menü",
                "name": "Antipasti",
                "offers": [{
                    "priceKind": "included",
                    "basis": "per_item",
                }],
                "declarationCodes": [],
            }],
            "documentDeclarations": [],
        }
        draft = {
            "sections": [{
                "title": text("Menü"),
                "entries": [{
                    "name": text("Antipasti"),
                    "offers": [{
                        "priceKind": "included",
                        "amountCents": None,
                        "deltaCents": None,
                        "minimumAmountCents": None,
                        "maximumAmountCents": None,
                        "currencyCode": "EUR",
                        "rawPrice": None,
                        "basis": "per_item",
                        "evidence": evidence("Antipasti"),
                    }],
                    "quantities": [],
                    "optionGroups": [],
                    "bundleComponents": [],
                    "declarations": [],
                }],
                "subsections": [],
            }],
            "declarations": [],
            "processing": {
                "pageOutcomes": [{
                    "pageIndex": 0,
                    "status": "processed",
                    "attempts": 1,
                    "latencyMilliseconds": 100,
                }]
            },
        }

        result = quality_gate.score_document(
            manifest,
            truth,
            {"draft": draft, "draftValidationErrors": []},
            mode="local",
        )

        self.assertEqual(result["offerCounts"]["f1"], 1)
        self.assertEqual(result["safety"]["inventedPrices"], 0)

    def test_repeatability_uses_exact_semantic_pairwise_agreement(self):
        manifest = {
            "documents": [{"fixtureID": "fixture"}],
        }
        stable_snapshot = {
            "id": "fixture",
            "draft": {
                "sections": [{
                    "id": "generated-a",
                    "title": text("Dessert"),
                    "entries": [{
                        "id": "entry-a",
                        "quantities": [{"id": "quantity-a", "rawText": "0,2 l"}],
                        "offers": [{
                            "id": "offer-a",
                            "appliesToQuantityID": "quantity-a",
                        }],
                    }],
                }],
                "declarations": [],
                "reviewFindings": [],
            },
        }
        same_with_different_ids = {
            "id": "fixture",
            "draft": {
                "sections": [{
                    "id": "generated-b",
                    "title": text("Dessert"),
                    "entries": [{
                        "id": "entry-b",
                        "quantities": [{"id": "quantity-b", "rawText": "0,2 l"}],
                        "offers": [{
                            "id": "offer-b",
                            "appliesToQuantityID": "quantity-b",
                        }],
                    }],
                }],
                "declarations": [],
                "reviewFindings": [],
            },
        }
        changed_snapshot = {
            "id": "fixture",
            "draft": {
                "sections": [{"id": "generated-c", "title": text("Getränke")}],
                "declarations": [],
                "reviewFindings": [],
            },
        }
        reports = [
            {"menus": [stable_snapshot]},
            {"menus": [same_with_different_ids]},
            {"menus": [changed_snapshot]},
        ]

        result = quality_gate.measure_repeatability(reports, manifest, "local")

        self.assertEqual(result["repeatRuns"], 3)
        self.assertAlmostEqual(result["exactSemanticRepeatability"], 1 / 3)
        self.assertEqual(result["documents"][0]["uniqueSemanticOutputs"], 2)

    def test_wrong_category_fails_category_assignment_even_when_entry_matches(self):
        manifest = {
            "fixtureID": "fixture",
            "pages": [{"pageIndex": 0, "pageKind": "menu"}],
        }
        truth = {
            "sections": [{"pageIndex": 0, "title": "Dessert"}],
            "entries": [{
                "pageIndex": 0,
                "section": "Dessert",
                "name": "Sorbet",
                "offers": [],
                "declarationCodes": [],
            }],
            "documentDeclarations": [],
        }
        draft = {
            "sections": [{
                "title": text("Getränke"),
                "entries": [{
                    "name": text("Sorbet"),
                    "offers": [],
                    "quantities": [],
                    "optionGroups": [],
                    "bundleComponents": [],
                    "declarations": [],
                }],
                "subsections": [],
            }],
            "declarations": [],
            "processing": {
                "pageOutcomes": [{
                    "pageIndex": 0,
                    "status": "processed",
                    "attempts": 1,
                    "latencyMilliseconds": 100,
                }]
            },
        }

        result = quality_gate.score_document(
            manifest,
            truth,
            {"draft": draft, "draftValidationErrors": []},
            mode="local",
        )

        self.assertEqual(result["entryCounts"]["f1"], 1)
        self.assertEqual(result["categoryAssignment"]["accuracy"], 0)

    def test_release_checks_failures_in_every_repeat_run(self):
        manifest = {
            "fixtureID": "fixture",
            "pages": [{"pageIndex": 0, "pageKind": "cover"}],
        }
        truth = {
            "sections": [],
            "entries": [],
            "documentDeclarations": [],
        }

        def scored(status, validation_errors):
            draft = {
                "sections": [],
                "declarations": [],
                "processing": {
                    "pageOutcomes": [{
                        "pageIndex": 0,
                        "status": status,
                        "attempts": 1,
                        "latencyMilliseconds": 100,
                    }]
                },
            }
            return quality_gate.score_document(
                manifest,
                truth,
                {
                    "draft": draft,
                    "draftValidationErrors": validation_errors,
                },
                mode="local",
            )

        first = scored("empty", [])
        second = scored("fallback", ["invalid draft"])
        run_documents = [[first], [second]]
        run_metrics = [
            quality_gate.aggregate_results(documents)
            for documents in run_documents
        ]
        policy = {
            "measurementTargets": {},
            "hardSafetyGates": {"maximumValidationErrors": 0},
            "operationalTargets": {"maximumPageFailureRate": 0},
        }

        failures = quality_gate.release_enforcement_failures(
            run_documents,
            run_metrics,
            {
                "repeatRuns": 2,
                "exactSemanticRepeatability": 1,
                "documents": [],
            },
            policy,
        )

        self.assertTrue(any("run 2: pageFailureRate" in item for item in failures))
        self.assertTrue(any("run 2: validationErrors" in item for item in failures))


class PolicyProfileTests(unittest.TestCase):
    """The gate carries two threshold profiles.

    `launch` is the release-relevant bar for a review-assisted import; `strict`
    is a diagnostic long-term target that no stochastic extractor can pass,
    because it requires near-exact repeatability across runs.
    """

    GATE_DIR = (
        Path(__file__).resolve().parents[2]
        / "docs"
        / "test-fixtures"
        / "scanner-quality-gate"
    )

    def real_policy(self):
        return quality_gate.read_json(self.GATE_DIR / "policy.json")

    def test_shipped_policy_defines_both_profiles_and_a_valid_default(self):
        policy = self.real_policy()

        self.assertIn("launch", policy["profiles"])
        self.assertIn("strict", policy["profiles"])
        self.assertIn(policy["defaultProfile"], policy["profiles"])

    def test_launch_profile_does_not_require_exact_repeatability(self):
        # This is the whole point of the split: demanding near-exact
        # repeatability from a sampled model is unreachable by construction, so
        # the release bar must not contain it.
        launch = quality_gate.resolve_policy_profile(self.real_policy(), "launch")
        strict = quality_gate.resolve_policy_profile(self.real_policy(), "strict")

        self.assertNotIn(
            "minimumExactSemanticRepeatability",
            launch["operationalTargets"],
        )
        self.assertIn(
            "minimumExactSemanticRepeatability",
            strict["operationalTargets"],
        )

    def test_launch_profile_gates_unrecoverable_losses_only(self):
        launch = quality_gate.resolve_policy_profile(self.real_policy(), "launch")
        gates = launch["hardSafetyGates"]

        # A human resolves these in the review before publishing.
        self.assertNotIn("maximumInventedItems", gates)
        self.assertNotIn("maximumInventedPrices", gates)
        # A review cannot recover any of these.
        self.assertEqual(gates["maximumMissingItems"], 0)
        self.assertEqual(gates["maximumSilentPageLosses"], 0)
        self.assertEqual(gates["maximumForbiddenClaimHits"], 0)
        self.assertEqual(gates["maximumValidationErrors"], 0)

    def test_unknown_profile_is_rejected(self):
        with self.assertRaises(ValueError):
            quality_gate.resolve_policy_profile(self.real_policy(), "erfunden")

    def test_policy_without_profiles_is_used_as_its_own_profile(self):
        legacy = {"measurementTargets": {"entryF1": 0.5}}

        self.assertEqual(
            quality_gate.resolve_policy_profile(legacy, "launch"),
            legacy,
        )

    def test_maximum_targets_flag_a_budget_overrun(self):
        policy = {"maximumTargets": {"correctionsPerPage": 3.0}}

        self.assertEqual(
            quality_gate.enforcement_failures(
                {"correctionsPerPage": 2.9, "safety": {}, "operational": {}},
                policy,
                include_repeatability=False,
            ),
            [],
        )
        failures = quality_gate.enforcement_failures(
            {"correctionsPerPage": 4.2, "safety": {}, "operational": {}},
            policy,
            include_repeatability=False,
        )
        self.assertTrue(any("correctionsPerPage 4.200 > 3.000" in f for f in failures))

    def test_maximum_targets_report_an_unmeasured_metric(self):
        failures = quality_gate.enforcement_failures(
            {"safety": {}, "operational": {}},
            {"maximumTargets": {"correctionsPerPage": 3.0}},
            include_repeatability=False,
        )

        self.assertIn("correctionsPerPage not measured", failures)

    def test_corrections_per_page_counts_every_manual_repair(self):
        def document(missing, invented, invented_prices, pages):
            empty_counts = {
                "truePositive": 0,
                "falsePositive": 0,
                "falseNegative": 0,
            }
            return {
                key: dict(empty_counts)
                for key in (
                    "sectionCounts",
                    "entryCounts",
                    "descriptionCounts",
                    "offerCounts",
                    "relationCounts",
                    "declarationCounts",
                    "noticeCounts",
                    "translationCounts",
                    "nameExact",
                    "descriptionExact",
                )
            } | {
                "categoryAssignment": {"correct": 0, "total": 0},
                "priceFields": {
                    "rawTextExact": {"correct": 0, "total": 0},
                    "basis": {"correct": 0, "total": 0},
                    "currency": {"correct": 0, "total": 0},
                },
                "evidence": {"total": 0, "correct": 0, "supported": 0},
                "groundTruthEvidence": {"total": 0, "correct": 0},
                "reviews": {"expected": [], "actual": []},
                "missingDraft": False,
                "safety": {
                    "missingItems": missing,
                    "inventedItems": invented,
                    "inventedPrices": invented_prices,
                    "forbiddenClaimHits": 0,
                    "coverFalsePositives": 0,
                    "silentPageLosses": 0,
                    "validationErrors": 0,
                },
                "operational": {
                    "selectedPages": pages,
                    "failedPages": 0,
                    "pageLatenciesMilliseconds": [100] * pages,
                    "attempts": pages,
                    "retries": 0,
                    "provider": None,
                    "model": None,
                    "tokenUsage": {},
                },
            }

        metrics = quality_gate.aggregate_results([document(2, 3, 5, 10)])

        self.assertAlmostEqual(metrics["correctionsPerPage"], 1.0)


if __name__ == "__main__":
    unittest.main()
