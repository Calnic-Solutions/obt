/// Which role acts on a Set at each workflow status.
///
/// The one place this mapping lives. `WorkQueue.stageMeta` pairs the same
/// statuses with labels and icons for the workbench; `AudioNeeds` uses this
/// to decide whose recordings are worth downloading. If a stage ever changes
/// hands, both have to agree, so it is stated once.
const Map<String, String> kStageRoles = {
  'not_started': 'drafter',
  'recorded': 'drafter',
  'redo': 'drafter',
  'community_setup': 'drafter',
  'community_test': 'drafter',
  'approved': 'drafter',
  'peer': 'peer',
  'community_review': 'peer',
  'back_translation': 'back_translator',
  'consultant': 'consultant',
};
