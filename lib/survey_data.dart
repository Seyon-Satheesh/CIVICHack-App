/// The onboarding survey (same questions as the CivicSpeak web demo).
class SurveyQuestion {
  const SurveyQuestion({required this.key, required this.title, required this.hint, required this.options, this.exclusive, this.max, this.other = false});
  final String key, title, hint;
  final List<SurveyOption> options;
  final String? exclusive;
  final int? max;
  final bool other;
}

class SurveyOption {
  const SurveyOption(this.key, this.title, [this.description = '']);
  final String key, title, description;
}

const surveyQuestions = <SurveyQuestion>[
  SurveyQuestion(key: 'q1', title: 'Which areas of city operations do you want to stay informed about?', hint: 'Select all that apply.', exclusive: 'none', options: [
      SurveyOption('planning', 'Urban Planning & Growth', 'New housing, zoning changes, heritage buildings'),
      SurveyOption('roads', 'Roads, Transit & Traffic', 'Construction, snow removal, bike lanes, parking, buses'),
      SurveyOption('parks', 'Parks, Recreation & Culture', 'Parks, trails, community centres, pools, libraries'),
      SurveyOption('bylaws', 'Neighbourhood Rules & Bylaws', 'Noise, property standards, short-term rentals, pets'),
      SurveyOption('budget', 'City Budgets & Taxes', 'Property taxes, fares, how city money is spent'),
      SurveyOption('safety', 'Emergency & Safety Services', 'Fire, paramedics, policing, bylaw enforcement'),
      SurveyOption('water', 'Water, Waste & Utilities', 'Garbage, recycling, drinking water, drainage'),
      SurveyOption('none', 'None of these', 'Only urgent local emergencies'),
    ]),
  SurveyQuestion(key: 'q2', title: 'Which decisions would you want a say in?', hint: 'Select up to 4.', exclusive: 'read', max: 4, options: [
      SurveyOption('building', 'New Building Projects Near Me', 'Heights, shadows, traffic, affordable housing'),
      SurveyOption('streets', 'Street Safety & Traffic Calming', 'Speed bumps, crosswalks, bike lanes'),
      SurveyOption('transit', 'Public Transit Improvements', 'Routes, stops, frequency, fares'),
      SurveyOption('parks', 'Park & Playground Redesigns', 'Playgrounds, splash pads, dog areas, trees'),
      SurveyOption('bylaws', 'Everyday Neighbourhood Bylaws', 'Rentals, patios, noise, backyard chickens'),
      SurveyOption('budget', 'Annual City Budget Trade-Offs', 'Taxes vs. services like library hours'),
      SurveyOption('policing', 'Community Safety Priorities', 'Police budgets and safety initiatives'),
      SurveyOption('read', 'I prefer to just read updates', 'Rather than take part'),
    ]),
  SurveyQuestion(key: 'q3', title: 'How much time can you give?', hint: 'Select all that fit.', options: [
      SurveyOption('quick', 'Quick & from home', '2–5 minute surveys, polls, maps'),
      SurveyOption('speak', 'Show up & speak up', 'Email my councillor, open houses, speak at a meeting'),
      SurveyOption('organize', 'Organize & mobilize', 'Neighbourhood association, volunteering'),
      SurveyOption('lead', 'Formal leadership', 'Citizen advisory committee or board'),
    ]),
  SurveyQuestion(key: 'q4', title: 'Any local issues you want updates on?', hint: 'Select all that apply.', other: true, options: [
      SurveyOption('intersection', 'An intersection or speeding problem near me'),
      SurveyOption('rezoning', 'A proposed condo or rezoning in my area'),
      SurveyOption('construction', 'Construction, road closures or snow clearing'),
      SurveyOption('park', 'Park maintenance, lighting or amenities'),
      SurveyOption('noise', 'Noise, parking or short-term rentals on my block'),
      SurveyOption('transitlocal', 'Transit delays or missing bus connections'),
      SurveyOption('tax', 'Property taxes or cost of living'),
      SurveyOption('other', 'Other'),
    ]),
];
