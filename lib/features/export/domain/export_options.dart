enum ExportTransactionFilter { all, expense, income }

enum ExportGrouping { none, category, type, day }

enum ExportSummaryLayout { compact, standard, executive }

enum ExportBrandTemplate { classic, minimal, ledger }

class ExportOptions {
  final ExportTransactionFilter transactionFilter;
  final ExportGrouping grouping;
  final ExportSummaryLayout summaryLayout;
  final ExportBrandTemplate brandTemplate;

  const ExportOptions({
    this.transactionFilter = ExportTransactionFilter.all,
    this.grouping = ExportGrouping.category,
    this.summaryLayout = ExportSummaryLayout.standard,
    this.brandTemplate = ExportBrandTemplate.classic,
  });
}
