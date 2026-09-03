#!/usr/bin/env python3
"""Reproducible, instrument-grouped analysis of an OrgRec comparative export."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import platform
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


FAMILY_COLORS = {
    "flute": "#2b8cbe",
    "diapason": "#31a354",
    "string": "#756bb1",
    "reed": "#de2d26",
    "compound": "#636363",
    "indeterminate": "#969696",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("corpus", type=Path, help="comparative-corpus.json from OrgRecDatasetTool")
    parser.add_argument("output", type=Path, help="directory for tables, figures, and report")
    parser.add_argument("--seed", type=int, default=20260831)
    parser.add_argument("--family-permutations", type=int)
    parser.add_argument("--classifier-permutations", type=int)
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def json_number(value: float | int | None):
    if value is None:
        return None
    value = float(value)
    return value if math.isfinite(value) else None


def dummy_matrix(values: list[str]) -> np.ndarray:
    levels = sorted(set(values))
    if len(levels) <= 1:
        return np.empty((len(values), 0), dtype=float)
    return np.asarray([[float(value == level) for level in levels[1:]] for value in values])


def residual_sum_squares(y: np.ndarray, matrix: np.ndarray) -> tuple[float, int]:
    coefficients, _, rank, _ = np.linalg.lstsq(matrix, y, rcond=None)
    residual = y - matrix @ coefficients
    return float(residual @ residual), int(rank)


def regression_matrices(
    instruments: list[str], labels: list[str], nuisance_columns: list[list[str]]
) -> tuple[np.ndarray, np.ndarray]:
    intercept = np.ones((len(instruments), 1), dtype=float)
    reduced = np.column_stack(
        [intercept, dummy_matrix(instruments)] + [dummy_matrix(values) for values in nuisance_columns]
    )
    full = np.column_stack([reduced, dummy_matrix(labels)])
    return reduced, full


def partial_association_statistic(
    y: np.ndarray, instruments: list[str], labels: list[str], nuisance_columns: list[list[str]]
) -> dict:
    reduced, full = regression_matrices(instruments, labels, nuisance_columns)
    rss_reduced, rank_reduced = residual_sum_squares(y, reduced)
    rss_full, rank_full = residual_sum_squares(y, full)
    effect_df = max(0, rank_full - rank_reduced)
    residual_df = max(0, len(y) - rank_full)
    delta = max(0.0, rss_reduced - rss_full)
    partial_r2 = delta / rss_reduced if rss_reduced > 1e-15 else 0.0
    f_value = None
    if effect_df > 0 and residual_df > 0 and rss_full > 1e-15:
        f_value = (delta / effect_df) / (rss_full / residual_df)
    return {
        "partial_r2": partial_r2,
        "f_statistic": f_value,
        "effect_df": effect_df,
        "residual_df": residual_df,
        "rss_reduced": rss_reduced,
        "rss_full": rss_full,
    }


def permute_within_instrument(values: list, instruments: list[str], rng: np.random.Generator) -> list:
    result = list(values)
    indexes: dict[str, list[int]] = defaultdict(list)
    for index, instrument in enumerate(instruments):
        indexes[instrument].append(index)
    for group in indexes.values():
        shuffled = [values[index] for index in group]
        rng.shuffle(shuffled)
        for index, value in zip(group, shuffled):
            result[index] = value
    return result


def benjamini_hochberg(p_values: list[float]) -> list[float]:
    count = len(p_values)
    order = sorted(range(count), key=p_values.__getitem__)
    adjusted = [1.0] * count
    running = 1.0
    for position in range(count - 1, -1, -1):
        index = order[position]
        candidate = p_values[index] * count / (position + 1)
        running = min(running, candidate)
        adjusted[index] = min(1.0, running)
    return adjusted


def run_association_tests(
    matrix: np.ndarray,
    feature_names: list[str],
    selected_features: list[str],
    instruments: list[str],
    labels: list[str],
    nuisance_columns: list[list[str]],
    nuisance_description: str,
    permutation_count: int,
    rng: np.random.Generator,
    endpoint_prefix: str,
) -> list[dict]:
    rows = []
    for feature in selected_features:
        feature_index = feature_names.index(feature)
        y = matrix[:, feature_index]
        observed = partial_association_statistic(y, instruments, labels, nuisance_columns)
        reduced, _ = regression_matrices(instruments, labels, nuisance_columns)
        reduced_coefficients, _, _, _ = np.linalg.lstsq(reduced, y, rcond=None)
        fitted = reduced @ reduced_coefficients
        residuals = y - fitted
        exceedances = 0
        for _ in range(permutation_count):
            permuted_residuals = np.asarray(permute_within_instrument(residuals.tolist(), instruments, rng))
            null_y = fitted + permuted_residuals
            null = partial_association_statistic(null_y, instruments, labels, nuisance_columns)
            exceedances += null["partial_r2"] >= observed["partial_r2"] - 1e-15
        p_value = (exceedances + 1) / (permutation_count + 1)
        rows.append({
            "analysis": endpoint_prefix,
            "feature": feature,
            "rank_count": len(labels),
            "instrument_count": len(set(instruments)),
            "label_count": len(set(labels)),
            "nuisance_adjustment": nuisance_description,
            "permutation_method": "Freedman-Lane residuals within instrument",
            "partial_r2": observed["partial_r2"],
            "f_statistic": observed["f_statistic"],
            "effect_df": observed["effect_df"],
            "residual_df": observed["residual_df"],
            "permutations": permutation_count,
            "p_value": p_value,
        })
    q_values = benjamini_hochberg([row["p_value"] for row in rows]) if rows else []
    for row, q_value in zip(rows, q_values):
        row["q_value_bh"] = q_value
    return rows


def standardize(training: np.ndarray, testing: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    center = np.median(training, axis=0)
    lower = np.percentile(training, 25, axis=0)
    upper = np.percentile(training, 75, axis=0)
    scale = upper - lower
    standard_deviation = np.std(training, axis=0)
    scale = np.where(scale > 1e-9, scale, np.where(standard_deviation > 1e-9, standard_deviation, 1.0))
    return (training - center) / scale, (testing - center) / scale


def classification_metrics(truth: list[str], predicted: list[str]) -> dict:
    if not truth:
        return {"accuracy": None, "macro_f1": None, "confusion": {}}
    labels = sorted(set(truth) | set(predicted))
    confusion = {actual: {guess: 0 for guess in labels} for actual in labels}
    for actual, guess in zip(truth, predicted):
        confusion[actual][guess] += 1
    f1_values = []
    for label in labels:
        true_positive = confusion[label][label]
        false_positive = sum(confusion[actual][label] for actual in labels if actual != label)
        false_negative = sum(confusion[label][guess] for guess in labels if guess != label)
        denominator = 2 * true_positive + false_positive + false_negative
        f1_values.append((2 * true_positive / denominator) if denominator else 0.0)
    return {
        "accuracy": sum(actual == guess for actual, guess in zip(truth, predicted)) / len(truth),
        "macro_f1": float(np.mean(f1_values)),
        "confusion": confusion,
    }


def leave_one_instrument_out(
    matrix: np.ndarray,
    labels: list[str],
    instruments: list[str],
    feature_indexes: list[int],
) -> tuple[dict, list[dict]]:
    truth: list[str] = []
    predicted: list[str] = []
    accepted_truth: list[str] = []
    accepted_predicted: list[str] = []
    prediction_rows: list[dict] = []
    for held_out in sorted(set(instruments)):
        train_indexes = [i for i, value in enumerate(instruments) if value != held_out]
        test_indexes = [i for i, value in enumerate(instruments) if value == held_out]
        if not train_indexes or not test_indexes:
            continue
        training, testing = standardize(
            matrix[np.ix_(train_indexes, feature_indexes)],
            matrix[np.ix_(test_indexes, feature_indexes)],
        )
        training_labels = [labels[index] for index in train_indexes]
        available = sorted(set(training_labels))
        if len(available) < 2:
            continue
        centroids = {
            label: np.mean(training[[i for i, value in enumerate(training_labels) if value == label]], axis=0)
            for label in available
        }
        own_distances = [
            float(np.linalg.norm(training[i] - centroids[training_labels[i]]))
            for i in range(len(training_labels))
        ]
        ood_threshold = float(np.percentile(own_distances, 95)) if own_distances else math.inf
        for local_index, source_index in enumerate(test_indexes):
            distances = {label: float(np.linalg.norm(testing[local_index] - centroid)) for label, centroid in centroids.items()}
            guess = min(distances, key=distances.get)
            distance = distances[guess]
            accepted = distance <= ood_threshold
            actual = labels[source_index]
            truth.append(actual)
            predicted.append(guess)
            if accepted:
                accepted_truth.append(actual)
                accepted_predicted.append(guess)
            prediction_rows.append({
                "held_out_instrument": held_out,
                "row_index": source_index,
                "actual_family": actual,
                "predicted_family": guess,
                "nearest_centroid_distance": distance,
                "training_ood_threshold_95pct": ood_threshold,
                "accepted": accepted,
                "actual_family_available_in_training": actual in available,
            })
    metrics = classification_metrics(truth, predicted)
    accepted = classification_metrics(accepted_truth, accepted_predicted)
    metrics.update({
        "rank_count": len(truth),
        "instrument_count": len(set(instruments)),
        "accepted_rank_count": len(accepted_truth),
        "accepted_coverage": len(accepted_truth) / len(truth) if truth else None,
        "accepted_accuracy": accepted["accuracy"],
    })
    return metrics, prediction_rows


def classifier_permutation_test(
    matrix: np.ndarray,
    labels: list[str],
    instruments: list[str],
    feature_indexes: list[int],
    observed_accuracy: float | None,
    count: int,
    rng: np.random.Generator,
) -> float | None:
    if observed_accuracy is None or count <= 0:
        return None
    exceedances = 0
    usable = 0
    for _ in range(count):
        permuted = permute_within_instrument(labels, instruments, rng)
        null, _ = leave_one_instrument_out(matrix, permuted, instruments, feature_indexes)
        if null["accuracy"] is not None:
            usable += 1
            exceedances += null["accuracy"] >= observed_accuracy - 1e-15
    return (exceedances + 1) / (usable + 1)


def pca(matrix: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    center = np.median(matrix, axis=0)
    scale = np.percentile(matrix, 75, axis=0) - np.percentile(matrix, 25, axis=0)
    scale = np.where(scale > 1e-9, scale, np.where(np.std(matrix, axis=0) > 1e-9, np.std(matrix, axis=0), 1.0))
    standardized = (matrix - center) / scale
    u, singular, vt = np.linalg.svd(standardized, full_matrices=False)
    scores = u * singular
    denominator = max(1, len(matrix) - 1)
    variances = singular**2 / denominator
    explained = variances / np.sum(variances) if np.sum(variances) else np.zeros_like(variances)
    return scores, vt.T, explained


def make_pca_figure(path: Path, scores: np.ndarray, labels: list[str], explained: np.ndarray) -> None:
    figure, axis = plt.subplots(figsize=(8, 6), constrained_layout=True)
    for family in sorted(set(labels)):
        indexes = [index for index, label in enumerate(labels) if label == family]
        axis.scatter(
            scores[indexes, 0],
            scores[indexes, 1] if scores.shape[1] > 1 else np.zeros(len(indexes)),
            label=family,
            color=FAMILY_COLORS.get(family, "#636363"),
            alpha=0.72,
            edgecolors="white",
            linewidths=0.35,
            s=38,
        )
    pc1 = explained[0] * 100 if len(explained) else 0
    pc2 = explained[1] * 100 if len(explained) > 1 else 0
    axis.set_xlabel(f"PC1 ({pc1:.1f}% variance)")
    axis.set_ylabel(f"PC2 ({pc2:.1f}% variance)")
    axis.set_title("OrgRec rank timbre features (descriptive PCA)")
    axis.axhline(0, color="#cccccc", linewidth=0.6)
    axis.axvline(0, color="#cccccc", linewidth=0.6)
    axis.legend(title="Documentary family", frameon=False)
    figure.savefig(path.with_suffix(".png"), dpi=180)
    svg_path = path.with_suffix(".svg")
    figure.savefig(svg_path)
    plt.close(figure)
    normalize_svg(svg_path)


def normalize_svg(path: Path) -> None:
    """Keep deterministic generated SVG text friendly to Git whitespace checks."""
    lines = path.read_text(encoding="utf-8").splitlines()
    path.write_text("\n".join(line.rstrip() for line in lines) + "\n", encoding="utf-8")


def make_primary_figure(
    path: Path, matrix: np.ndarray, feature_names: list[str], primary: list[str], labels: list[str]
) -> None:
    indexes = [feature_names.index(feature) for feature in primary]
    pairs = [(0, 1), (0, 2), (1, 2)]
    short_labels = ["Normalized centroid", "Slope (dB/octave)", "Even/odd ratio (dB)"]
    figure, axes = plt.subplots(1, 3, figsize=(14, 5.2), constrained_layout=True)
    for axis, (left, right) in zip(axes, pairs):
        for family in sorted(set(labels)):
            rows = [row for row, label in enumerate(labels) if label == family]
            axis.scatter(
                matrix[rows, indexes[left]], matrix[rows, indexes[right]], label=family,
                color=FAMILY_COLORS.get(family, "#636363"), alpha=0.68, edgecolors="white",
                linewidths=0.3, s=34,
            )
        axis.set_xlabel(short_labels[left])
        axis.set_ylabel(short_labels[right])
    handles, legend_labels = axes[0].get_legend_handles_labels()
    figure.legend(
        handles, legend_labels, title="Documentary family", frameon=False,
        loc="upper center", bbox_to_anchor=(0.5, 1.01), ncol=4,
    )
    figure.suptitle("Prespecified OrgRec rank-level spectral endpoints", y=1.10)
    figure.savefig(path.with_suffix(".png"), dpi=180, bbox_inches="tight")
    svg_path = path.with_suffix(".svg")
    figure.savefig(svg_path, bbox_inches="tight")
    plt.close(figure)
    normalize_svg(svg_path)


def format_number(value, digits: int = 3) -> str:
    if value is None or not math.isfinite(float(value)):
        return "NA"
    return f"{float(value):.{digits}f}"


def main() -> int:
    args = parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with args.corpus.open(encoding="utf-8") as handle:
        study = json.load(handle)
    if study.get("contractVersion") != "orgrec-comparative-stop-timbre-study/1":
        raise SystemExit(f"Unsupported study contract: {study.get('contractVersion')!r}")

    source_ranks = study["ranks"]
    feature_names = study["featureNames"]
    if not source_ranks:
        raise SystemExit("The study export contains no rank records.")
    source_matrix = np.asarray([rank["featureValues"] for rank in source_ranks], dtype=float)
    if source_matrix.shape != (len(source_ranks), len(feature_names)) or not np.all(np.isfinite(source_matrix)):
        raise SystemExit("Rank feature matrix is malformed or contains non-finite values.")
    primary = study["parameters"]["primaryFeatureNames"]
    centroid_domain = study["parameters"]["normalizedCentroidDomain"]
    slope_domain = study["parameters"]["slopeDomainDBPerOctave"]
    centroid_index = feature_names.index("median.centroid")
    slope_index = feature_names.index("median.slopeDBPerOctave")
    analysis_indexes = [
        index for index in range(len(source_ranks))
        if centroid_domain[0] <= source_matrix[index, centroid_index] <= centroid_domain[1]
        and slope_domain[0] <= source_matrix[index, slope_index] <= slope_domain[1]
    ]
    excluded_indexes = sorted(set(range(len(source_ranks))) - set(analysis_indexes))
    ranks = [source_ranks[index] for index in analysis_indexes]
    matrix = source_matrix[analysis_indexes]
    analysis_exclusions = [{
        "record_id": source_ranks[index]["recordID"],
        "instrument_id": source_ranks[index]["instrumentID"],
        "source_label": source_ranks[index]["sourceLabel"],
        "median_centroid": source_matrix[index, centroid_index],
        "median_slope_db_per_octave": source_matrix[index, slope_index],
        "reason": (
            f"Rank median outside frozen timbre domain: centroid {centroid_domain[0]}..{centroid_domain[1]}, "
            f"slope {slope_domain[0]}..{slope_domain[1]} dB/octave. Retained in comparative-corpus.json."
        ),
    } for index in excluded_indexes]
    write_csv(
        args.output / "analysis-exclusions.csv",
        ["record_id", "instrument_id", "source_label", "median_centroid", "median_slope_db_per_octave", "reason"],
        analysis_exclusions,
    )
    if not ranks:
        raise SystemExit("No ranks remain inside the frozen primary timbre domains.")
    instruments = [rank["instrumentID"] for rank in ranks]
    families = [rank["documentaryFamily"] for rank in ranks]
    names = [rank["canonicalStopName"] for rank in ranks]
    footages = [rank.get("footage") or "(unknown)" for rank in ranks]
    family_permutations = args.family_permutations
    if family_permutations is None:
        family_permutations = int(study["parameters"]["familyPermutationCount"])
    classifier_permutations = args.classifier_permutations
    if classifier_permutations is None:
        classifier_permutations = int(study["parameters"]["classifierPermutationCount"])
    rng = np.random.default_rng(args.seed)

    family_tests = run_association_tests(
        matrix, feature_names, primary, instruments, families, [footages],
        "instrument+footage fixed effects", family_permutations, rng, "documentary_family"
    )
    minimum_name_instruments = int(study["parameters"]["minimumIndependentInstrumentsPerExactName"])
    name_instruments: dict[str, set[str]] = defaultdict(set)
    for name, instrument in zip(names, instruments):
        if name:
            name_instruments[name].add(instrument)
    eligible_names = sorted(name for name, members in name_instruments.items() if len(members) >= minimum_name_instruments)
    name_indexes = [index for index, name in enumerate(names) if name in eligible_names]
    name_tests: list[dict] = []
    if len(eligible_names) >= 2 and len(set(instruments[index] for index in name_indexes)) >= 3:
        name_tests = run_association_tests(
            matrix[name_indexes],
            feature_names,
            primary,
            [instruments[index] for index in name_indexes],
            [names[index] for index in name_indexes],
            [
                [footages[index] for index in name_indexes],
                [families[index] for index in name_indexes],
            ],
            "instrument+footage+documentary-family fixed effects",
            family_permutations,
            rng,
            "canonical_stop_name",
        )
    association_rows = family_tests + name_tests
    write_csv(
        args.output / "association-tests.csv",
        [
            "analysis", "feature", "rank_count", "instrument_count", "label_count", "nuisance_adjustment",
            "permutation_method", "partial_r2", "f_statistic", "effect_df", "residual_df", "permutations",
            "p_value", "q_value_bh",
        ],
        association_rows,
    )

    name_rows = []
    for name in sorted(name_instruments):
        indexes = [index for index, value in enumerate(names) if value == name]
        row = {
            "canonical_stop_name": name,
            "rank_count": len(indexes),
            "instrument_count": len(name_instruments[name]),
            "eligible_for_confirmatory_name_test": name in eligible_names,
            "source_labels": " | ".join(sorted(set(ranks[index]["sourceLabel"] for index in indexes))),
            "documentary_families": " | ".join(sorted(set(families[index] for index in indexes))),
        }
        for feature in primary:
            row[f"median_{feature}"] = float(np.median(matrix[indexes, feature_names.index(feature)]))
        name_rows.append(row)
    write_csv(
        args.output / "stop-name-summary.csv",
        [
            "canonical_stop_name", "rank_count", "instrument_count", "eligible_for_confirmatory_name_test",
            "source_labels", "documentary_families",
        ] + [f"median_{feature}" for feature in primary],
        name_rows,
    )

    primary_indexes = [feature_names.index(feature) for feature in primary]
    all_indexes = list(range(len(feature_names)))
    classifier_rows = []
    classifier_details = {}
    for model_name, feature_indexes in [("primary_endpoints", primary_indexes), ("all_rank_features", all_indexes)]:
        metrics, predictions = leave_one_instrument_out(matrix, families, instruments, feature_indexes)
        p_value = classifier_permutation_test(
            matrix, families, instruments, feature_indexes, metrics["accuracy"], classifier_permutations, rng
        )
        classifier_details[model_name] = {**metrics, "permutation_p_value": p_value}
        classifier_rows.append({
            "model": model_name,
            "feature_count": len(feature_indexes),
            "rank_count": metrics["rank_count"],
            "instrument_count": metrics["instrument_count"],
            "accuracy": metrics["accuracy"],
            "macro_f1": metrics["macro_f1"],
            "accepted_rank_count": metrics["accepted_rank_count"],
            "accepted_coverage": metrics["accepted_coverage"],
            "accepted_accuracy": metrics["accepted_accuracy"],
            "permutations": classifier_permutations,
            "permutation_p_value": p_value,
        })
        for prediction in predictions:
            prediction["model"] = model_name
            prediction["record_id"] = ranks[prediction.pop("row_index")]["recordID"]
        write_csv(
            args.output / f"classification-predictions-{model_name}.csv",
            [
                "model", "record_id", "held_out_instrument", "actual_family", "predicted_family",
                "nearest_centroid_distance", "training_ood_threshold_95pct", "accepted",
                "actual_family_available_in_training",
            ],
            predictions,
        )
    write_csv(
        args.output / "classification-summary.csv",
        [
            "model", "feature_count", "rank_count", "instrument_count", "accuracy", "macro_f1",
            "accepted_rank_count", "accepted_coverage", "accepted_accuracy", "permutations",
            "permutation_p_value",
        ],
        classifier_rows,
    )

    scores, loadings, explained = pca(matrix)
    score_rows = [{
        "record_id": rank["recordID"],
        "instrument_id": rank["instrumentID"],
        "documentary_family": rank["documentaryFamily"],
        "canonical_stop_name": rank["canonicalStopName"],
        **{f"PC{index + 1}": float(scores[row_index, index]) for index in range(min(6, scores.shape[1]))},
    } for row_index, rank in enumerate(ranks)]
    write_csv(
        args.output / "pca-scores.csv",
        ["record_id", "instrument_id", "documentary_family", "canonical_stop_name"]
        + [f"PC{index + 1}" for index in range(min(6, scores.shape[1]))],
        score_rows,
    )
    loading_rows = [{
        "feature": feature,
        **{f"PC{index + 1}": float(loadings[row_index, index]) for index in range(min(6, loadings.shape[1]))},
    } for row_index, feature in enumerate(feature_names)]
    write_csv(
        args.output / "pca-loadings.csv",
        ["feature"] + [f"PC{index + 1}" for index in range(min(6, loadings.shape[1]))],
        loading_rows,
    )
    make_pca_figure(args.output / "pca", scores, families, explained)
    make_primary_figure(args.output / "primary-endpoints", matrix, feature_names, primary, families)

    git_commit = None
    try:
        git_commit = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=Path(__file__).resolve().parents[2], check=True,
            capture_output=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        pass
    reproducibility = {
        "contract": "orgrec-comparative-stop-timbre-analysis-run/1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "command": " ".join(sys.argv),
        "input_path": str(args.corpus.resolve()),
        "input_sha256": sha256(args.corpus),
        "analysis_script_path": str(Path(__file__).resolve()),
        "analysis_script_sha256": sha256(Path(__file__).resolve()),
        "git_commit": git_commit,
        "python": sys.version,
        "numpy": np.__version__,
        "matplotlib": matplotlib.__version__,
        "platform": platform.platform(),
        "seed": args.seed,
        "family_permutations": family_permutations,
        "classifier_permutations": classifier_permutations,
        "thread_environment_variables_used": [],
    }
    (args.output / "reproducibility.json").write_text(
        json.dumps(reproducibility, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    family_counts = Counter(families)
    source_family_counts = Counter(rank["documentaryFamily"] for rank in source_ranks)
    producer_by_instrument = {}
    for rank in ranks:
        producer_by_instrument.setdefault(rank["instrumentID"], rank.get("producer") or "(unspecified)")
    producer_counts = Counter(producer_by_instrument.values())
    significant = [row for row in family_tests if row["q_value_bh"] <= 0.05 + 1e-12]
    best_classifier = next(row for row in classifier_rows if row["model"] == "primary_endpoints")
    summary = {
        "contract": "orgrec-comparative-stop-timbre-analysis-summary/1",
        "study_contract": study["contractVersion"],
        "study_parameter_sha256": study["parameterSHA256"],
        "source_rank_count": len(source_ranks),
        "analysis_rank_count": len(ranks),
        "analysis_exclusion_count": len(analysis_exclusions),
        "pipe_count": len(study["pipes"]),
        "instrument_count": len(set(instruments)),
        "family_counts": dict(sorted(family_counts.items())),
        "source_family_counts": dict(sorted(source_family_counts.items())),
        "instrument_counts_by_producer": dict(sorted(producer_counts.items())),
        "canonical_name_count": len(name_instruments),
        "eligible_canonical_name_count": len(eligible_names),
        "primary_family_tests": [{key: json_number(row.get(key)) if key in {"partial_r2", "f_statistic", "p_value", "q_value_bh"} else row.get(key) for key in row} for row in family_tests],
        "primary_name_tests": [{key: json_number(row.get(key)) if key in {"partial_r2", "f_statistic", "p_value", "q_value_bh"} else row.get(key) for key in row} for row in name_tests],
        "classifier": classifier_details,
        "pca_explained_variance_first_six": [float(value) for value in explained[:6]],
        "warnings": study["warnings"],
    }
    (args.output / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    family_test_lines = "\n".join(
        f"- `{row['feature']}`: partial R² {format_number(row['partial_r2'])}, "
        f"permutation p {format_number(row['p_value'])}, BH q {format_number(row['q_value_bh'])}."
        for row in family_tests
    )
    name_test_lines = "\n".join(
        f"- `{row['feature']}`: partial R² {format_number(row['partial_r2'])}, "
        f"permutation p {format_number(row['p_value'])}, BH q {format_number(row['q_value_bh'])}."
        for row in name_tests
    ) or "- No eligible inferential exact-name contrast was available; the name table is descriptive."
    report = f"""# Comparative stop-name and spectral analysis

## Result in brief

The frozen export contains **{len(source_ranks)} ranks** and **{len(study['pipes'])} analyzed pipe samples**. **{len(ranks)} ranks** from **{len(set(instruments))} independent virtual-organ instruments** lie inside the prespecified OrgRec centroid/slope domains and enter inference; **{len(analysis_exclusions)}** out-of-domain rank(s) remain preserved and are listed in `analysis-exclusions.csv`. Analysis-set documentary-family counts are {', '.join(f'{key}: {value}' for key, value in sorted(family_counts.items()))}. These labels are weak supervision inferred from stop names, not independent expert annotations.

The ten contributing instruments come from {len(producer_counts)} dataset producer groups ({', '.join(f'{key}: {value}' for key, value in sorted(producer_counts.items()))}). Instrument-grouped validation prevents rank leakage but cannot establish producer-independent transport when one producer supplies most organs.

The prespecified instrument-adjusted tests found **{len(significant)} of {len(family_tests)} primary endpoints** at BH q ≤ 0.05. The primary-endpoint nearest-centroid model, evaluated by leaving each entire instrument out, obtained accuracy **{format_number(best_classifier['accuracy'])}** and macro-F1 **{format_number(best_classifier['macro_f1'])}** (within-instrument label-permutation p **{format_number(best_classifier['permutation_p_value'])}**). This is a test of transport across sampled instruments, not a claim of universal organ-stop recognition.

## Primary family association tests

Each full linear model adds documentary family to a reduced model containing instrument and footage fixed effects. The effect is partial R². Its p-value comes from {family_permutations} Freedman–Lane permutations: reduced-model residuals are permuted separately within each instrument, then added to the fitted nuisance model. Benjamini–Hochberg correction covers the three prespecified spectral endpoints.

{family_test_lines}

## Stop-name analysis

There are **{len(name_instruments)}** canonical lexical stop names. **{len(eligible_names)}** meet the prespecified minimum of {minimum_name_instruments} independent instruments. Name tests condition on instrument, footage, and documentary family, so they ask whether lexical names add association beyond the broad family label. Names pool documented footages only after that adjustment. Source spellings and per-rank footage remain in the exported tables.

{name_test_lines}

## Validation design

- The rank, rather than each pipe, is the analysis unit. Pipes are repeated observations nested within ranks; ranks are nested within instruments.
- Every classifier fold withholds one complete instrument. Centering, scaling, centroids, and the descriptive 95th-percentile abstention threshold are estimated from that fold's training instruments only.
- The primary model uses only normalized spectral centroid, Hergert weighted slope, and even/odd energy. The 32-feature model is secondary and exploratory.
- PCA is descriptive, robustly scaled, and never used as inferential evidence.

## Boundaries of inference

VPO recordings are heterogeneous documentary sources. Producer processing, microphones, room response, tuning, level normalization, noise reduction, loop editing, and package sample selection are confounded with organ identity. Family assignments arise from text rules. Consequently, significant results establish reproducible association in this corpus, not causal construction mechanisms or population-wide classification accuracy. Absent significance is likewise inconclusive when only a few instruments are available.

The current retrieved-corpus adapter performs exact semantic sample mapping for GrandOrgue definitions. The separate source audit reports the much larger native collection and identifies Hauptwerk and other formats as pending adapters; adding those adapters extends the same immutable study contract without changing this statistical protocol.

## Reproducibility and outputs

`reproducibility.json` records the exact input and script hashes, software versions, seed, command, and Git commit. Machine-readable results are in `summary.json`; inferential tables and predictions are CSV; PCA is provided as PNG and SVG. Re-running the recorded command with the same input, environment, and seed reproduces all numerical results (timestamps and absolute paths excepted).

## Scientific basis

- Hergert F, Höper N. *Envelope Functions for Sound Spectra of Pipe Organ Ranks and the Influence of Pitch on Tonal Timbre*. Proceedings of Meetings on Acoustics. 2022;49:035012. <https://doi.org/10.1121/2.0001673>
- Peeters G, Giordano BL, Susini P, Misdariis N, McAdams S. *The Timbre Toolbox*. Journal of the Acoustical Society of America. 2011;130(5):2902–2916. <https://doi.org/10.1121/1.3642604>
- Benjamini Y, Hochberg Y. *Controlling the false discovery rate*. Journal of the Royal Statistical Society B. 1995;57(1):289–300. <https://doi.org/10.1111/j.2517-6161.1995.tb02031.x>
- Freedman DA, Lane D. *A Nonstochastic Interpretation of Reported Significance Levels*. Journal of Business & Economic Statistics. 1983;1(4):292–298. <https://doi.org/10.1080/07350015.1983.10509354>
- Schwarz G. *Estimating the dimension of a model*. Annals of Statistics. 1978;6(2):461–464. <https://doi.org/10.1214/aos/1176344136>
"""
    (args.output / "RESULTS.md").write_text(report, encoding="utf-8")
    print(f"Analyzed {len(ranks)} ranks from {len(set(instruments))} instruments; wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
