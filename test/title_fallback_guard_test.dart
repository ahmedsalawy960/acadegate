import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 test('mid-body sentence is never promoted to the title',() async {
 const text='Draft version June 17, 2019 Typeset using LaTeX twocolumn style.\n'
 'AyushiSingh,1 Christopher D. Matzner,1 and Peter H. Jumper2\n'
 '1Department of Astronomy and Astrophysics, University of Toronto, 50 St. George Street, Toronto.\n'
 'ABSTRACT\n'
 'The virial ratio between kinetic and gravitational terms provides key insight into the balance of forces that confine interstellar clouds.\n'
 '1. INTRODUCTION\n'
 'Equilibrium interstellar structures, if strongly self-gravitating and supported by thermal pressure, have virial ratios of order two.\n'
 'In this work we note that Interpretations of molecular cloud observations often rely on the virial ratio for estimating the stability of clouds in nearby galaxies today.\n'
 'Then a is sometimes estimated from the apparent density profile but otherwise assumed to take a certain constant value in the literature.\n'
 'We compute the ratio directly for every cloud in the sample and compare with previous indirect estimates in Section 3.\n'
 'References\n'
 '1. Smith, J. et al. Convergence of iterative solvers for sparse systems. J. Numer. Methods 12, 410-422 (2020).\n'
 '2. Doe, A. et al. Error bounds for finite element meshes. Comput. Methods 12, 515-540 (2018).\n'
 '3. Roe, K. et al. Adaptive refinement strategies. SIAM Rev. 60, 515-540 (2018).';
 final parsed=ManuscriptDocumentParser.parsePlainTextForTest(text);
 final applied=await ManuscriptDocumentParser.applyParseResult(manuscript:const PublishManuscript(userId:'probe',title:''),parsed:parsed,replaceReferences:true,replaceBody:true);
 expect(applied.title,'');
 });
}
