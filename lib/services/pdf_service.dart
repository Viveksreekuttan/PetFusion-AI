// lib/services/pdf_service.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'pet_model.dart';

class PdfService {
  static Future<Uint8List> generateDiagnosisReport({
    required Pet pet,
    required Map<String, dynamic> diagnosisData,
    required String doctorName,
    required Uint8List imageBytes,
  }) async {
    final pdf = pw.Document();

    final String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final String refId = DateTime.now().millisecondsSinceEpoch.toString().substring(8);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // HEADER
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'VetFusionAI', 
                    style: pw.TextStyle(
                      fontSize: 24, 
                      fontWeight: pw.FontWeight.bold, 
                      color: PdfColors.blue
                    )
                  ),
                  pw.Text(
                    'MEDICAL REPORT', 
                    style: pw.TextStyle(
                      fontSize: 18, 
                      fontWeight: pw.FontWeight.bold
                    )
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // PATIENT INFO
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400)
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Patient: ${pet.name}', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
                      ),
                      pw.Text('Species: ${pet.species} (${pet.breed})'),
                      pw.Text('Age: ${pet.age} | Gender: ${pet.gender}'),
                      pw.Text('Owner: ${pet.ownerName}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: $dateStr'),
                      pw.Text('Ref ID: #$refId'),
                      pw.Text('Consultant: $doctorName'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // SCANNED IMAGE
            pw.Text(
              'Scanned Image:', 
              style: pw.TextStyle(
                fontSize: 12, 
                fontWeight: pw.FontWeight.bold, 
                color: PdfColors.grey700
              )
            ),
            pw.SizedBox(height: 5),
            pw.Center(
              child: pw.Container(
                height: 200,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey)
                ),
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // DIAGNOSIS SUMMARY
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    'DIAGNOSIS: ', 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      diagnosisData['diagnosis_summary'] ?? 'Pending analysis...'
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // CONFIDENCE SCORE
            pw.Text('AI Confidence Score: ${diagnosisData['confidence_score'] ?? 0}%'),
            pw.SizedBox(height: 20),

            // DETAILED ANALYSIS
            pw.Text(
              'Clinical Findings & Analysis:', 
              style: pw.TextStyle(
                fontSize: 14, 
                fontWeight: pw.FontWeight.bold, 
                decoration: pw.TextDecoration.underline
              )
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              diagnosisData['detailed_analysis'] ?? 'No details provided.',
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
            ),
            pw.SizedBox(height: 20),

            // DISEASE PREDICTIONS SECTION
            if (diagnosisData['predicted_diseases'] != null && 
                (diagnosisData['predicted_diseases'] is List) && 
                (diagnosisData['predicted_diseases'] as List).isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue200),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'AI-Powered Disease Predictions:', 
                      style: pw.TextStyle(
                        fontSize: 14, 
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      )
                    ),
                    pw.SizedBox(height: 8),
                    ...(diagnosisData['predicted_diseases'] as List).map(
                      (disease) => pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(
                                  child: pw.Text(
                                    disease['disease_name']?.toString() ?? 'Unknown',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                pw.Text(
                                  'Probability: ${disease['probability']}%',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.blue700,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Severity: ${disease['severity']?.toString() ?? 'Unknown'}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: _getSeverityColor(disease['severity']?.toString() ?? ''),
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              disease['description']?.toString() ?? 'No description',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // RISK FACTORS SECTION
            if (diagnosisData['risk_factors'] != null && 
                (diagnosisData['risk_factors'] is List) && 
                (diagnosisData['risk_factors'] as List).isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  border: pw.Border.all(color: PdfColors.orange200),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Risk Factors:', 
                      style: pw.TextStyle(
                        fontSize: 14, 
                        fontWeight: pw.FontWeight.bold, 
                        color: PdfColors.orange900,
                      )
                    ),
                    pw.SizedBox(height: 5),
                    ...(diagnosisData['risk_factors'] as List).map(
                      (risk) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('• ', style: const pw.TextStyle(fontSize: 11)),
                            pw.Expanded(
                              child: pw.Text(
                                risk.toString(),
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // MEDICATIONS
            if (diagnosisData['medications'] != null && 
                (diagnosisData['medications'] is List) && 
                (diagnosisData['medications'] as List).isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.purple50,
                  border: pw.Border.all(color: PdfColors.purple200),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Recommended Treatment Plan:', 
                      style: pw.TextStyle(
                        fontSize: 14, 
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple900,
                      )
                    ),
                    pw.SizedBox(height: 5),
                    ...(diagnosisData['medications'] as List).map(
                      (med) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('• ', style: const pw.TextStyle(fontSize: 11)),
                            pw.Expanded(
                              child: pw.Text(
                                med.toString(),
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // PREVENTIVE MEASURES SECTION
            if (diagnosisData['preventive_measures'] != null && 
                (diagnosisData['preventive_measures'] is List) && 
                (diagnosisData['preventive_measures'] as List).isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Preventive Measures:', 
                      style: pw.TextStyle(
                        fontSize: 14, 
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green900,
                      )
                    ),
                    pw.SizedBox(height: 5),
                    ...(diagnosisData['preventive_measures'] as List).map(
                      (measure) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('• ', style: const pw.TextStyle(fontSize: 11)),
                            pw.Expanded(
                              child: pw.Text(
                                measure.toString(),
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // FOLLOW-UP RECOMMENDATION
            if (diagnosisData['next_checkup_days'] != null) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: PdfColors.amber200),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'Next Check-up: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                    ),
                    pw.Text(
                      'Recommended in ${diagnosisData['next_checkup_days']} days',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // DISCLAIMER
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'DISCLAIMER: This report is generated by AI-assisted diagnostic tools and should be used as a supplementary aid. '
                'Final diagnosis and treatment decisions should always be made by a licensed veterinary professional after physical examination.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ),

            // FOOTER
            pw.Spacer(),
            pw.Divider(thickness: 1),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated by VetFusionAI - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', 
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)
                ),
                pw.Text(
                  'AI-Powered Veterinary Diagnostics', 
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)
                ),
              ],
            ),
          ];
        },
        
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // Helper function to get color based on severity
  static PdfColor _getSeverityColor(String severity) {
    final lowerSeverity = severity.toLowerCase();
    if (lowerSeverity.contains('severe') || lowerSeverity.contains('critical')) {
      return PdfColors.red700;
    } else if (lowerSeverity.contains('moderate')) {
      return PdfColors.orange700;
    } else if (lowerSeverity.contains('mild')) {
      return PdfColors.yellow700;
    } else if (lowerSeverity.contains('none') || lowerSeverity.contains('normal')) {
      return PdfColors.green700;
    }
    return PdfColors.grey700;
  }
}