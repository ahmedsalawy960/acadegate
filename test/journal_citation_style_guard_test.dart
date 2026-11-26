import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/citation_style_picker.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 JournalFormatRules partial(Map<String,dynamic> extra)=>JournalFormatRules.fromExtracted(journalName:'Unseen journal',sourceUrl:'https://example.org/guide',extracted:{'found':true,'lineSpacing':1.5,...extra});
 for(final value in [null,'','other','unsupported-style']){
 test('partial guide style $value stays unresolved, independent of fallback',(){
 final r=JournalFormatRules.fromExtracted(journalName:'Unknown',sourceUrl:'https://example.org/guide',fallback:JournalFormatRules.forStudentStyle(PublishCitationStyle.ieee),extracted:{'found':true,'lineSpacing':1.5,'citationStyle':value});
 expect(r.citationStyleResolved,false);expect(r.lineSpacing,1.5);expect(r.copyWith(fontFamily:'Arial').citationStyleResolved,false);
 expect(r.confidenceLabel(isEnglish:true),contains('unresolved'));
 expect(r.ruleDescriptions(isEnglish:true).first,isNot(contains('APA')));
 });}
 test('explicit ambiguity wins over a parseable reference example',(){
 final r=partial({'citationStyleUnresolved':true,'citationStyle':'apa','referenceExample':'Smith, A. (2020). A scientific study. Science, 2, 1-4.'});
 expect(r.citationStyleResolved,false);
 });
 test('explicit named style resolves while user override is separately labeled',(){
 final r=partial({'citationStyle':'vancouver'});expect(r.citationStyleResolved,true);expect(r.citationStyleChosenByUser,false);
 final chosen=partial({}).withCitationStyle(PublishCitationStyle.apa);expect(chosen.citationStyleResolved,true);expect(chosen.citationStyleChosenByUser,true);expect(chosen.lineSpacing,1.5);expect(chosen.confidenceLabel(isEnglish:true),contains('selected by you'));
 expect(chosen.copyWith(marginTwips:1000).citationStyleChosenByUser,true);
 });
 test('student style retains explicit selection without guide guard',(){expect(JournalFormatRules.forStudentStyle(PublishCitationStyle.apa).citationStyleResolved,true);});
 test('actual DOCX rejects partial guide before converting references',()async{
 final m=PublishManuscript(userId:'qa',title:'QA style guard',body:'Scientific text [1].',references:const[PublishReference(id:'r',type:ReferenceType.journal,title:'An original work',rawText:'Smith A. An original work. Science. 2020;2:1-4.')]);
 final r=partial({});await expectLater(ManuscriptDocxExportService.instance.buildDocx(manuscript:m,rules:r),throwsStateError);
 expect(m.references.single.rawText,'Smith A. An original work. Science. 2020;2:1-4.');
 final bytes=await ManuscriptDocxExportService.instance.buildDocx(manuscript:m,rules:r.withCitationStyle(PublishCitationStyle.vancouver));expect(bytes.length,greaterThan(1000));
 });
 testWidgets('unresolved picker has no preselected APA and accepts explicit same-default choice',(tester)async{
 if(Platform.environment['QA_STYLE_SCREENSHOT']!=null) { await tester.runAsync(()async{
 final font=FontLoader('QAReadable')..addFont(File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf').readAsBytes().then((b)=>ByteData.sublistView(b)));await font.load();
 final icons=FontLoader('MaterialIcons')..addFont(File('/tmp/flutter-qa/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes().then((b)=>ByteData.sublistView(b)));await icons.load();
 }); }
 PublishCitationStyle? selected;final boundary=GlobalKey();
 await tester.pumpWidget(MaterialApp(theme:ThemeData(fontFamily:'QAReadable',splashFactory:NoSplash.splashFactory),locale:const Locale('en'),home:Scaffold(body:RepaintBoundary(key:boundary,child:ColoredBox(color:Colors.white,child:Padding(padding:const EdgeInsets.all(24),child:SizedBox(width:500,child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Partial guide rules - reference style unresolved'),const SizedBox(height:20),CitationStylePicker(value:null,onChanged:(s)=>selected=s)]))))))));
 expect(find.text('APA'),findsNothing);expect(selected,isNull);
 if(Platform.environment['QA_STYLE_SCREENSHOT']!=null){
 await tester.runAsync(()async{
 final image=await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio:2);
 final data=await image.toByteData(format:ui.ImageByteFormat.png);File(Platform.environment['QA_STYLE_SCREENSHOT']!).writeAsBytesSync(data!.buffer.asUint8List());
 });
 }
 await tester.tap(find.byType(DropdownButtonFormField<PublishCitationStyle>));await tester.pumpAndSettle();
 await tester.tap(find.textContaining('APA').last);await tester.pumpAndSettle();expect(selected,PublishCitationStyle.apa);
 });
}
