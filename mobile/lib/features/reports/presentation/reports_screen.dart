import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../payroll/data/payroll_repository.dart';
import '../../payroll/data/payroll_summary.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    _endDate = _startDate.add(const Duration(days: 6));
  }

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(payrollSummariesByRangeProvider(
      (startDate: _startDate, endDate: _endDate),
    ));
    final money = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ');
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    return AsyncValueView(
      value: summaries,
      data: (items) {
        final filtered = items
            .where((item) =>
                item.employeeName
                    .toLowerCase()
                    .contains(_query.toLowerCase()) ||
                item.employeeCode.toLowerCase().contains(_query.toLowerCase()))
            .toList();
        final total =
            filtered.fold(0.0, (sum, item) => sum + item.totalPayable);
        final weeklyRows = _weeklyRows(filtered);
        final planRows = _planRows(filtered);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Reportes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '${dateFormat.format(_startDate)} - '
              '${dateFormat.format(_endDate)}',
            ),
            const SizedBox(height: 12),
            _DateFilters(
              startDate: _startDate,
              endDate: _endDate,
              onPickStart: () => _pickDate(isStart: true),
              onPickEnd: () => _pickDate(isStart: false),
              onCurrentWeek: _setCurrentWeek,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar trabajador',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            _TotalStrip(
              total: money.format(total),
              employees: filtered.length,
              lines: planRows.length,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: filtered.isEmpty
                        ? null
                        : () => _sharePdf(filtered, money),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF pagos'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: filtered.isEmpty
                        ? null
                        : () => _shareExcel(filtered, money),
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Excel'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle(
              icon: Icons.stacked_bar_chart_outlined,
              title: 'Semanal por tipo de trabajo',
            ),
            const SizedBox(height: 8),
            if (weeklyRows.isEmpty)
              const Text('Sin trabajos confirmados en el rango.')
            else
              for (final row in weeklyRows)
                Card(
                  child: ListTile(
                    title: Text(row.workTypeName),
                    subtitle: Text('${row.quantity} ${_unitLabel(row.unit)}'),
                    trailing: Text(money.format(row.total)),
                  ),
                ),
            const SizedBox(height: 16),
            const _SectionTitle(
              icon: Icons.grid_on_outlined,
              title: 'Planilla',
            ),
            const SizedBox(height: 8),
            _PlanillaTable(rows: planRows, money: money),
            const SizedBox(height: 16),
            const _SectionTitle(
              icon: Icons.receipt_long_outlined,
              title: 'Comprobantes por trabajador',
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const Text('Sin trabajadores para comprobante.')
            else
              for (final item in filtered)
                Card(
                  child: ListTile(
                    title: Text('${item.employeeCode} - ${item.employeeName}'),
                    subtitle: Text('${item.lines.length} lineas'),
                    trailing: Text(money.format(item.totalPayable)),
                    onTap: () => _shareEmployeePdf(item, money),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: isStart ? _startDate : _endDate,
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate.isAfter(_endDate)) _startDate = _endDate;
      }
    });
  }

  void _setCurrentWeek() {
    final today = DateTime.now();
    setState(() {
      _startDate = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: today.weekday - 1));
      _endDate = _startDate.add(const Duration(days: 6));
    });
  }

  List<_WeeklyWorkTypeRow> _weeklyRows(
    List<EmployeePayrollSummary> summaries,
  ) {
    final grouped = <String, _WeeklyWorkTypeRow>{};
    for (final summary in summaries) {
      for (final line in summary.lines) {
        final key = '${line.workTypeId}-${line.unit}';
        final current = grouped[key];
        grouped[key] = _WeeklyWorkTypeRow(
          workTypeName: line.workTypeName,
          unit: line.unit,
          quantity: (current?.quantity ?? 0) + line.quantity,
          total: (current?.total ?? 0) + (line.subtotal ?? 0),
        );
      }
    }
    return grouped.values.toList()
      ..sort((a, b) => a.workTypeName.compareTo(b.workTypeName));
  }

  List<_PlanillaRow> _planRows(List<EmployeePayrollSummary> summaries) {
    final rows = <_PlanillaRow>[];
    for (final summary in summaries) {
      for (final line in summary.lines) {
        rows.add(
          _PlanillaRow(
            employeeCode: summary.employeeCode,
            employeeName: summary.employeeName,
            workDate: line.workDate,
            workTypeName: line.workTypeName,
            unit: line.unit,
            quantity: line.quantity,
            rate: line.rate,
            subtotal: line.subtotal,
          ),
        );
      }
    }
    return rows
      ..sort((a, b) {
        final codeCompare =
            _compareEmployeeCode(a.employeeCode, b.employeeCode);
        if (codeCompare != 0) return codeCompare;
        return a.workDate.compareTo(b.workDate);
      });
  }

  Future<void> _shareExcel(
    List<EmployeePayrollSummary> summaries,
    NumberFormat money,
  ) async {
    final bytes = _buildExcel(summaries, money);
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        name: 'planilla-v04.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    ]);
  }

  Uint8List _buildExcel(
    List<EmployeePayrollSummary> summaries,
    NumberFormat money,
  ) {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Planilla'];
    sheet.appendRow([
      xl.TextCellValue('Codigo'),
      xl.TextCellValue('Trabajador'),
      xl.TextCellValue('Fecha'),
      xl.TextCellValue('Trabajo'),
      xl.TextCellValue('Unidad'),
      xl.TextCellValue('Cantidad'),
      xl.TextCellValue('Precio'),
      xl.TextCellValue('Subtotal'),
    ]);

    for (final row in _planRows(summaries)) {
      sheet.appendRow([
        xl.TextCellValue(row.employeeCode),
        xl.TextCellValue(row.employeeName),
        xl.TextCellValue(DateFormat('dd/MM/yyyy').format(row.workDate)),
        xl.TextCellValue(row.workTypeName),
        xl.TextCellValue(_unitLabel(row.unit)),
        xl.DoubleCellValue(row.quantity),
        xl.DoubleCellValue(row.rate ?? 0),
        xl.DoubleCellValue(row.subtotal ?? 0),
      ]);
    }

    final weekly = excel['Semanal por tipo'];
    weekly.appendRow([
      xl.TextCellValue('Trabajo'),
      xl.TextCellValue('Unidad'),
      xl.TextCellValue('Cantidad'),
      xl.TextCellValue('Total'),
    ]);
    for (final row in _weeklyRows(summaries)) {
      weekly.appendRow([
        xl.TextCellValue(row.workTypeName),
        xl.TextCellValue(_unitLabel(row.unit)),
        xl.DoubleCellValue(row.quantity),
        xl.DoubleCellValue(row.total),
      ]);
    }

    final summary = excel['Resumen'];
    summary.appendRow([
      xl.TextCellValue('Trabajadores'),
      xl.IntCellValue(summaries.length),
    ]);
    summary.appendRow([
      xl.TextCellValue('Total'),
      xl.TextCellValue(
        money.format(
          summaries.fold(0.0, (sum, item) => sum + item.totalPayable),
        ),
      ),
    ]);

    excel.delete('Sheet1');
    return Uint8List.fromList(excel.save() ?? []);
  }

  Future<void> _sharePdf(
    List<EmployeePayrollSummary> summaries,
    NumberFormat money,
  ) async {
    final bytes = await _buildPdf(summaries, money);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'reporte-pagos.pdf',
    );
  }

  Future<void> _shareEmployeePdf(
    EmployeePayrollSummary summary,
    NumberFormat money,
  ) async {
    final bytes = await _buildEmployeePdf(summary, money);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'comprobante-${summary.employeeCode}.pdf',
    );
  }

  Future<Uint8List> _buildEmployeePdf(
    EmployeePayrollSummary summary,
    NumberFormat money,
  ) async {
    final rows = _employeeReceiptRows(summary);
    final doc = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Resumen de pago',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('${summary.employeeCode} - ${summary.employeeName}'),
          pw.Text(
            '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Trabajo', 'Semana 1', 'Semana 2', 'Precio/un', 'Total'],
            data: [
              for (final row in rows)
                [
                  row.workTypeName,
                  _formatNumber(row.week1Quantity),
                  _formatNumber(row.week2Quantity),
                  money.format(row.rate),
                  money.format(row.total),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600),
              ),
              child: pw.Text(
                'PAGO: ${money.format(summary.totalPayable)}',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> _buildPdf(
    List<EmployeePayrollSummary> summaries,
    NumberFormat money,
  ) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#17494c'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CONTROL LABORAL',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Reporte de pagos',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          for (final item in summaries) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${item.employeeCode} - ${item.employeeName}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        item.isPaid ? 'Se pago' : 'Pendiente',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    headers: ['Trabajo', 'Cantidad', 'Precio', 'Subtotal'],
                    data: [
                      for (final line in item.lines)
                        [
                          line.workTypeName,
                          '${line.quantity} ${_unitLabel(line.unit)}',
                          money.format(line.rate ?? 0),
                          money.format(line.subtotal ?? 0),
                        ],
                    ],
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    headerDecoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellStyle: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Por cancelar: ${money.format(item.totalPayable)}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );
    return doc.save();
  }

  List<_EmployeeReceiptRow> _employeeReceiptRows(
    EmployeePayrollSummary summary,
  ) {
    final week1End = _startDate.add(const Duration(days: 6));
    final grouped = <String, _EmployeeReceiptRow>{};

    for (final line in summary.lines) {
      final current = grouped[line.workTypeId] ??
          _EmployeeReceiptRow(
            workTypeName: line.workTypeName,
            week1Quantity: 0,
            week2Quantity: 0,
            rate: line.rate ?? 0,
            total: 0,
          );
      final inWeek1 = !line.workDate.isAfter(week1End);
      grouped[line.workTypeId] = _EmployeeReceiptRow(
        workTypeName: current.workTypeName,
        week1Quantity: current.week1Quantity + (inWeek1 ? line.quantity : 0),
        week2Quantity: current.week2Quantity + (inWeek1 ? 0 : line.quantity),
        rate: line.rate ?? current.rate,
        total: current.total + (line.subtotal ?? 0),
      );
    }

    return grouped.values.toList()
      ..sort((a, b) => a.workTypeName.compareTo(b.workTypeName));
  }
}

class _DateFilters extends StatelessWidget {
  const _DateFilters({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onCurrentWeek,
  });

  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onCurrentWeek;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM', 'es_BO');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onPickStart,
          icon: const Icon(Icons.event_outlined),
          label: Text('Desde ${dateFormat.format(startDate)}'),
        ),
        OutlinedButton.icon(
          onPressed: onPickEnd,
          icon: const Icon(Icons.event_available_outlined),
          label: Text('Hasta ${dateFormat.format(endDate)}'),
        ),
        TextButton.icon(
          onPressed: onCurrentWeek,
          icon: const Icon(Icons.today_outlined),
          label: const Text('Semana actual'),
        ),
      ],
    );
  }
}

class _TotalStrip extends StatelessWidget {
  const _TotalStrip({
    required this.total,
    required this.employees,
    required this.lines,
  });

  final String total;
  final int employees;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: _Metric(label: 'Total', value: total)),
            Expanded(
                child: _Metric(label: 'Trabajadores', value: '$employees')),
            Expanded(child: _Metric(label: 'Lineas', value: '$lines')),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PlanillaTable extends StatelessWidget {
  const _PlanillaTable({required this.rows, required this.money});

  final List<_PlanillaRow> rows;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('Sin datos para la planilla.');

    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Codigo')),
            DataColumn(label: Text('Trabajador')),
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Trabajo')),
            DataColumn(label: Text('Cant.')),
            DataColumn(label: Text('Precio')),
            DataColumn(label: Text('Subtotal')),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  DataCell(Text(row.employeeCode)),
                  DataCell(Text(row.employeeName)),
                  DataCell(Text(dateFormat.format(row.workDate))),
                  DataCell(Text(row.workTypeName)),
                  DataCell(Text('${row.quantity} ${_unitLabel(row.unit)}')),
                  DataCell(Text(money.format(row.rate ?? 0))),
                  DataCell(Text(money.format(row.subtotal ?? 0))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyWorkTypeRow {
  const _WeeklyWorkTypeRow({
    required this.workTypeName,
    required this.unit,
    required this.quantity,
    required this.total,
  });

  final String workTypeName;
  final String unit;
  final double quantity;
  final double total;
}

class _PlanillaRow {
  const _PlanillaRow({
    required this.employeeCode,
    required this.employeeName,
    required this.workDate,
    required this.workTypeName,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.subtotal,
  });

  final String employeeCode;
  final String employeeName;
  final DateTime workDate;
  final String workTypeName;
  final String unit;
  final double quantity;
  final double? rate;
  final double? subtotal;
}

class _EmployeeReceiptRow {
  const _EmployeeReceiptRow({
    required this.workTypeName,
    required this.week1Quantity,
    required this.week2Quantity,
    required this.rate,
    required this.total,
  });

  final String workTypeName;
  final double week1Quantity;
  final double week2Quantity;
  final double rate;
  final double total;
}

int _compareEmployeeCode(String a, String b) {
  final numberA = int.tryParse(a.trim());
  final numberB = int.tryParse(b.trim());
  if (numberA != null && numberB != null && numberA != numberB) {
    return numberA.compareTo(numberB);
  }
  return a.compareTo(b);
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

String _unitLabel(String value) {
  return switch (value) {
    'hour' => 'h',
    'unit' => 'unid.',
    'service' => 'serv.',
    'bag' => 'bolsa',
    'bucket' => 'tacho',
    'tray' => 'bandeja',
    _ => value,
  };
}
