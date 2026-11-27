import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 test('online resource with [Online]. Available marker becomes web',(){
 const text='Body text about haemoglobin thresholds and nutrition surveys.\n'
 'References\n'
 '1. Organization, W. H. 2011. Haemoglobin concentrations for the diagnosis of anaemia and assessment of severity. [Online]. Geneva. Available: https://www.who.int/vmnis/indicators/haemoglobin.pdf\n'
 '2. Weir, C. B. & Jan, A. 2020. BMI Classification Percentile And Cut Off Points. [Online]. Treasure Island: StatPearls Publishing. Available: https://www.ncbi.nlm.nih.gov/books/NBK541070/';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,2);
 expect(refs[0].type,ReferenceType.web);
 expect(refs[1].type,ReferenceType.web);
 expect(refs[0].url,'https://www.who.int/vmnis/indicators/haemoglobin.pdf');
 });
 test('ieee journal with volume and pages stays journal despite [Online]',(){
 const text='Body text about prosthetic hand control with electromyography signals.\n'
 'References\n'
 '[1] A. H. Al-Timemy, G. Bugmann, J. Escudero, and N. Outram, "Classification of finger movements for the dexterous hand prosthesis control with surface electromyography," IEEE J. Biomed. Health Inform., vol. 17, no. 3, pp. 608-618, 2013. [Online]. Available: https://ieeexplore.ieee.org/document/1234567';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,1);
 expect(refs[0].type,ReferenceType.journal);
 });
 test('retrieved-from alone does not flip a journal reference',(){
 const text='Body text about pharmacovigilance of herbal medicines in practice.\n'
 'References\n'
 '1. Bigoniya, P. (2009). Pharmacovigilance of herbal medicines: Current status and future strategies. The Pharma Review, 20, 51-54. Retrieved from https://www.researchgate.net/publication/12345';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,1);
 expect(refs[0].type,ReferenceType.journal);
 });
 test('doi.org link alone stays journal',(){
 const text='Body text about hypertension prevalence in sub-saharan africa.\n'
 'References\n'
 '1. Addo, J., Smeeth, L., & Leon, D. A. (2007). Hypertension in Sub-Saharan Africa. American Heart Association, 10(1161), 1012-1019. https://doi.org/10.1161/CIRCULATIONAHA.107.726192';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,1);
 expect(refs[0].type,ReferenceType.journal);
 });
 test('arabic online marker mutaah becomes web',(){
 const text='Body text about distance education platforms and student outcomes.\n'
 'References\n'
 '1. Smith, J. 2021. Digital learning platforms in higher education. [Online]. Cairo: Example Press. متاح: https://example.org/report.pdf';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,1);
 expect(refs[0].type,ReferenceType.web);
 });
}
