import 'advisor_agent.dart';

/// Which assistant tools each selected specialty may use.
///
/// When the user taps a specialist chip, the assistant commits to that
/// specialty: its persona is binding AND its tool set is limited to this
/// table, so the answer cannot pull in capabilities outside the specialty
/// (e.g. an editing answer never shows a "verified references" chip, because
/// the literature tool was never offered to the model).
///
/// Review table (tool names are the function declarations in
/// assistant_tools.dart):
///
/// | Specialty (chip)        | Allowed tools |
/// |-------------------------|---------------|
/// | فكرة بحثية              | literature, evidence, paper text, thesis file |
/// | كتابة الرسالة           | thesis file, draft, literature, paper text, translation |
/// | محاكاة البحث            | thesis file, draft, literature, evidence, labs |
/// | مراجعة الأدبيات         | literature, evidence, paper text, verify refs, thesis file, translation |
/// | التوثيق والمراجع        | verify refs, literature, paper text, draft |
/// | تحرير لغوي              | translation, draft |
/// | تحليل البيانات          | draft, thesis file |
/// | العروض                  | draft, thesis file |
/// | تخطيط بحث               | thesis file, draft, literature, evidence, labs |
/// | اختيار مشرف             | supervisors, thesis file, literature |
///
/// In auto mode (no chip selected) every tool stays available and the
/// assistant routes by the message text, as before.
const Map<AdvisorAgentId, Set<String>> advisorAgentAllowedTools = {
  AdvisorAgentId.researchIdea: {
    'search_scientific_literature',
    'check_research_evidence',
    'read_paper_text',
    'read_my_research_file',
  },
  AdvisorAgentId.thesisWriter: {
    'read_my_research_file',
    'ask_my_draft',
    'search_scientific_literature',
    'read_paper_text',
    'translate_academic_text',
  },
  AdvisorAgentId.researchSimulation: {
    'read_my_research_file',
    'ask_my_draft',
    'search_scientific_literature',
    'check_research_evidence',
    'search_labs_and_equipment',
  },
  AdvisorAgentId.literatureReview: {
    'search_scientific_literature',
    'check_research_evidence',
    'read_paper_text',
    'verify_references',
    'read_my_research_file',
    'translate_academic_text',
  },
  AdvisorAgentId.citations: {
    'verify_references',
    'search_scientific_literature',
    'read_paper_text',
    'ask_my_draft',
  },
  AdvisorAgentId.academicEditing: {
    'translate_academic_text',
    'ask_my_draft',
  },
  AdvisorAgentId.dataAnalysis: {
    'ask_my_draft',
    'read_my_research_file',
  },
  AdvisorAgentId.presentations: {
    'ask_my_draft',
    'read_my_research_file',
  },
  AdvisorAgentId.thesisPlanning: {
    'read_my_research_file',
    'ask_my_draft',
    'search_scientific_literature',
    'check_research_evidence',
    'search_labs_and_equipment',
  },
  AdvisorAgentId.supervisorMatch: {
    'find_supervisors',
    'read_my_research_file',
    'search_scientific_literature',
  },
  AdvisorAgentId.catalogExecute: {
    'search_store_products',
    'ask_my_draft',
  },
};
