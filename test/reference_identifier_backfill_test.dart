import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
void main(){
 test('bare doi without a doi: prefix is captured',(){
 const text='Body text about nanogenerator energy harvesting and self-powered sensing.\n'
 'References\n'
 '1. Khanapuram, U. K. et al. Harvesting energy from friction: the revolutionary decade of triboelectric nanogenerators. Adv. Powder Mater. 5, 100373; 10.1016/j.apmate.2025.100373. (2026).\n'
 '2. Chen, J. et al. Triboelectric nanogenerator-based self-powered resonant sensor for non-destructive defect detection. Sensors 19, 3262; 10.3390/s19153262 (2019).\n'
 '3. Wang, X. et al. A flexible triboelectric-piezoelectric hybrid nanogenerator based on P(VDF-TrFE) nanofibers for wearable devices. Sci. Rep. 6, 36409; 10.1038/srep36409 (2016).';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,3);
 expect(refs[0].doi,'10.1016/j.apmate.2025.100373');
 expect(refs[1].doi,'10.3390/s19153262');
 expect(refs[2].doi,'10.1038/srep36409');
 });
 test('non-doi web url fills the url field, doi.org goes to doi only',(){
 const text='Body text about anaemia diagnosis and body mass index classifications.\n'
 'References\n'
 '1. Weir, C. B. & Jan, A. 2020. BMI Classification Percentile And Cut Off Points. [Online]. Treasure Island: StatPearls Publishing. Available: https://www.ncbi.nlm.nih.gov/books/NBK541070/\n'
 '2. Addo, J., Smeeth, L., & Leon, D. A. (2007). Hypertension in Sub-Saharan Africa. American Heart Association, 10(1161), 1012-1019. https://doi.org/10.1161/CIRCULATIONAHA.107.726192\n'
 '3. Bunn, C., Fernandez-Kolb, P., & Lundy, M. (2019). Climate Smart Cocoa. CCAFS Info Note. https://hdl.handle.net/10568/103790';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,3);
 expect(refs[0].url,'https://www.ncbi.nlm.nih.gov/books/NBK541070/');
 expect(refs[0].doi,isEmpty);
 expect(refs[1].doi,'10.1161/CIRCULATIONAHA.107.726192');
 expect(refs[1].url,isEmpty);
 expect(refs[2].url,'https://hdl.handle.net/10568/103790');
 });
 test('volume-like numbers are not mistaken for a doi',(){
 const text='Body text about numerical methods in applied mathematics and statistics.\n'
 'References\n'
 '1. Smith, J. et al. Convergence of iterative solvers for sparse systems. J. Numer. Methods 110.1234/5 (2020).\n'
 '2. Doe, A. et al. Error bounds for finite element meshes. Comput. Methods 12, 410.1016-410.1020 (2018).\n'
 '3. Roe, K. et al. Adaptive refinement strategies. SIAM Rev. 60, 515-540 (2018).';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,3);
 expect(refs[0].doi,isEmpty);
 expect(refs[1].doi,isEmpty);
 expect(refs[2].doi,isEmpty);
 });
 test('garbage doi values are cleared',(){
 const text='Body text about deployment of machine learning algorithms on edge devices.\n'
 'References\n'
 '[1] A. H. Al-Timemy, G. Bugmann, J. Escudero, and N. Outram, "Classification of finger movements for the dexterous hand prosthesis control with surface electromyography," IEEE J. Biomed. Health Inform., vol. 17, no. 3, pp. 608-618, 2013.\n'
 'Stanford, CA, USA, Tech. Rep., 2021, pp. 1-222. [Online]. Available: https://aiindex.stanford.edu/report/, doi:\n'
 '[2] J. Betthauser et al., "Stable small-magnitude force control using a biologically-inspired tendon-driven hand," in Proc. IEEE/RSJ Int. Conf. Intell. Robots Syst., 2019, pp. 4388-4395.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,3);
 expect(refs[1].doi,isEmpty);
 expect(refs[1].url,'https://aiindex.stanford.edu/report/');
 });
}
