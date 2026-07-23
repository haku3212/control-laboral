import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../payroll/data/payroll_repository.dart';
import '../../payroll/data/payroll_summary.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(payrollSummariesProvider);
    final money = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ');

    return AsyncValueView(
      value: summaries,
      data: (items) {
        final filtered = items
            .where((item) =>
                item.employeeName.toLowerCase().contains(_query.toLowerCase()))
            .toList();
        final total =
            filtered.fold(0.0, (sum, item) => sum + item.totalPayable);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Reportes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Total filtrado: ${money.format(total)}'),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar trabajador',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
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
              ],
            ),
            const SizedBox(height: 16),
            for (final item in filtered)
              Card(
                child: ListTile(
                  title: Text(item.employeeName),
                  subtitle: Text(item.isPaid ? 'Pagado' : 'Pendiente'),
                  trailing: Text(money.format(item.totalPayable)),
                ),
              ),
          ],
        );
      },
    );
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
                        item.employeeName,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        item.isPaid ? 'Se pago' : 'Pendiente',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table.fromTextArray(
                    headers: ['Trabajo', 'Cantidad', 'Precio', 'Subtotal'],
                    data: [
                      for (final line in item.lines)
                        [
                          line.workTypeName,
                          '${line.quantity} ${line.unit}',
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
                      'A pagar: ${money.format(item.totalPayable)}',
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
}
