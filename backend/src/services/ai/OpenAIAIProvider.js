const OpenAI = require('openai');
const AIProvider = require('./AIProvider');
const env = require('../../config/env');

class OpenAIAIProvider extends AIProvider {
  constructor() {
    super();
    this.openai = new OpenAI({
      apiKey: env.openaiApiKey || env.apiKeys.ai,
    });
  }

  /**
   * Generates a structured, accurate MOM from meeting transcript using GPT-4o.
   *
   * KEY DESIGN PRINCIPLES:
   * 1. The MOM is 100% based on the actual spoken transcript — never on the meeting title.
   * 2. We use GPT-4o (not mini) for accurate instruction following on complex prompts.
   * 3. Speaker attribution is inferred from context, not from generic "Speaker 1/2" labels.
   * 4. Action items are split into individual tasks per person mentioned.
   */
  async generateMOM(meetingData, transcriptData, options = {}) {
    const rawTranscript =
      transcriptData.rawText ||
      (transcriptData.segments || []).map((s) => s.text).join(' ');

    if (!rawTranscript || rawTranscript.trim().length < 20) {
      return this._emptyMOM('No transcript available to generate MOM from.');
    }

    const participantsArray = Array.isArray(meetingData.participants) ? meetingData.participants : [];
    const participantsNumbered = participantsArray.map((n, i) => `${i + 1}. ${n}`).join('\n');

    // Historical meeting context for recurring teams (last 3 meetings)
    let historyBlock = '';
    if (Array.isArray(options.pastContext) && options.pastContext.length > 0) {
      historyBlock = `\nHISTORICAL CONTEXT (previous meetings, for continuity only):\n`;
      options.pastContext.forEach((p, idx) => {
        historyBlock += `[Past Meeting ${idx + 1}: "${p.title}"]\n`;
        historyBlock += `- Attendees: ${(p.participants || []).join(', ')}\n`;
        historyBlock += `- Summary: ${(p.summary || 'N/A').substring(0, 300)}\n`;
        historyBlock += `- Open Action Items: ${
          (p.actionItems || []).map((a) => `${a.owner}: ${a.task}`).join('; ') || 'None'
        }\n\n`;
      });
    }

    const systemPrompt = `You are an elite corporate Chief of Staff and certified business executive secretary producing world-class, market-standard Minutes of Meeting (MOM).

Your output must match the highest global corporate standards used in Fortune 500 enterprises, tech firms, and consulting organizations (McKinsey, BCG, Big 4).

═══════════════════════════════════════════
MARKET-STANDARD MOM GUIDELINES:
═══════════════════════════════════════════
1. PROFESSIONAL CORPORATE TONE:
   - Use crisp, objective, authoritative business language (e.g., "The team deliberated on...", "It was resolved to...", "Key dependencies were identified around...").
   - Eliminate colloquialisms, conversational filler words, stuttering, and informal banter.
   - Present information logically with high clarity, structure, and readability.

2. TOPIC CONSOLIDATION & UNIFIED CLUSTERING (CRITICAL - NO SPLIT TOPICS):
   - Consolidate all discussions belonging to the same project, application, feature, or theme into EXACTLY ONE comprehensive point in "keyDiscussionPoints".
   - Flow / Fragmentation Rule: If participants start discussing Project A (e.g., "Wafir Application"), get interrupted or divert to Project B (e.g., "Beeline Application"), and later return to Project A, DO NOT create multiple split points for Project A. Instead, synthesize and merge ALL information, updates, technical details, and decisions about Project A into ONE consolidated entry, and Project B into ONE separate entry.
   - Every discussion point MUST begin with a bold topic headline or subject tag, followed by substantive detail:
     Format: "**[Project / Topic Name]**: [Detailed consolidated synthesis of the discussion, context, figures, tools/platforms, and outcome. If a specific participant was explicitly named/identified as having driven this topic, note: (Initiated by [VerifiedName]) or ([VerifiedName] highlighted that...)]"
   - Under no circumstances make up or guess speaker names. If the speaker was NOT explicitly named in the conversation, do not invent one — simply present the business point with its topic header.

3. DEDUPLICATION & SYNTHESIS:
   - Eliminate repetitive conversations, repeated arguments, and duplicate talking points.
   - Merge redundant updates and statements into a single cohesive summary. Do not repeat the same discussion across multiple points.

4. NON-CORE, INFORMAL & FILLER TALK ROUTED TO "otherNotes":
   - Place all casual remarks, non-essential chatter, greetings, social banter, jokes, off-topic side discussions, and non-actionable talking strictly in "otherNotes".
   - Keep "keyDiscussionPoints" 100% clean, professional, and focused on core business, technical, and operational discussions.

5. ACCURATE ACTION ITEMS (SMART CRITERIA):
   - Every action item MUST be Specific, Measurable, Actionable, Relevant, and Time-bound.
   - "task": State with an action verb (e.g., "Prepare and circulate Q3 pipeline review deck", "Finalize API contract for authentication service").
   - "owner": Assign ONLY to an individual explicitly tasked or volunteered in the transcript (using their exact name from the VERIFIED PARTICIPANTS LIST). If unassigned or group-oriented, assign to "Team".
   - "deadline": Mention exact deadline/timeline if spoken (e.g., "End of week", "15th October", "Next sprint"), otherwise "TBD".
   - "priority": Assign "High" for blockers/critical path, "Medium" for regular deliverables, "Low" for exploratory tasks.

6. COMPREHENSIVE EXECUTIVE SUMMARY:
   - Structure into distinct, cohesive paragraphs:
     - Background & Purpose of the meeting.
     - Key operational/strategic discussions held.
     - Core decisions reached and consensus achieved.
     - Immediate operational horizon and delivery commitments.

7. ACCURACY & FIDELITY:
   - Base 100% of facts on the provided transcript.
   - Capture all specific numbers, budgets, headcounts, percentages, technologies, and deadlines mentioned.
   - Correct technical terminology (e.g., "Flutter", "VoIP", "Kubernetes", "Jira", "AWS", "Figma", "Stripe").
   - Replace phonetically garbled names with the exact match from VERIFIED PARTICIPANTS LIST (e.g., "Rajesh" -> "Rakesh", "Dharmic" -> "Dharmesh").

═══════════════════════════════════════════
REQUIRED JSON FORMAT:
═══════════════════════════════════════════
Respond strictly with valid JSON (no markdown fences, no backticks, no extra text):
{
  "meetingSummary": "Executive summary in 3-4 professional business paragraphs outlining meeting objective, critical discussion themes, resolutions, and forward commitments.",
  "agenda": [
    "Core Agenda Topic 1 discussed in meeting",
    "Core Agenda Topic 2",
    "..."
  ],
  "keyDiscussionPoints": [
    "**[Topic / Functional Area]**: 2-4 sentences providing deep substantive context, technical or business details, numbers/metrics discussed, and the consensus or resolution reached.",
    "**[Topic / Functional Area]**: 2-4 sentences describing another major segment of the meeting in full detail.",
    "..."
  ],
  "decisions": [
    "Formal decision agreed upon with rationales and constraints (e.g., 'Approved adoption of X architecture for Y service due to Z efficiency gains').",
    "..."
  ],
  "actionItems": [
    {
      "task": "Actionable task starting with an action verb with full context",
      "owner": "Exact verified participant name IF explicitly assigned, otherwise 'Team'",
      "deadline": "Spoken timeframe / date or 'TBD'",
      "priority": "High | Medium | Low"
    }
  ],
  "pendingItems": [
    "Unresolved question, blocker, or open dependency requiring further stakeholder review"
  ],
  "risks": [
    "Identified risk, challenge, or operational constraint explicitly discussed during the meeting"
  ],
  "nextSteps": [
    "Immediate next milestone or operational step"
  ],
  "otherNotes": [
    "Informal remarks, non-core discussions, casual banter, greetings, or secondary side topics that do not belong in main business points"
  ],
  "nextMeeting": {
    "date": "Spoken date or empty string",
    "time": "Spoken time or empty string"
  },
  "conclusion": "Formal concluding statement capturing overall meeting consensus, strategic alignment, and the path forward."
}`;

    const userPrompt = `VERIFIED PARTICIPANTS LIST:
${participantsNumbered || 'None specified'}

${historyBlock}MEETING DETAILS:
Title: ${meetingData.title || 'Business Meeting'}
Type: ${meetingData.meetingType || 'General'}
Location: ${meetingData.location || 'N/A'}
Stated Agenda: ${meetingData.agenda || 'N/A'}

FULL MEETING TRANSCRIPT:
---
${rawTranscript}
---

INSTRUCTIONS:
1. Generate market-standard, executive-grade corporate Minutes of Meeting.
2. Structure keyDiscussionPoints with professional topic headlines: "**[Topic]**: Detailed business context...".
3. CONSOLIDATE fragmented discussions: If a project/topic was started, interrupted, and resumed later, merge all related talk into a SINGLE point for that project. Never output duplicate points for the same project/topic.
4. Eliminate repetitive talking and deduplicate statements across the transcript.
5. Place casual remarks, greetings, social banter, or non-core informal discussions in "otherNotes" so they do not clutter the primary business discussion points.
6. Only attach a participant's name if they were explicitly named or clearly self-identified in the transcript. Never guess or invent speaker names.
7. Correct any phonetic mishearings using the VERIFIED PARTICIPANTS LIST.
8. Capture all commitments, metrics, decisions, and deadlines.`;

    const response = await this.openai.chat.completions.create({
      model: 'gpt-4o',           // Upgraded from gpt-4o-mini for accurate instruction following
      temperature: 0.1,          // Very low temperature for factual, consistent output
      max_tokens: 4096,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
    });

    const content = response.choices[0].message.content;
    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.error('[AI] Failed to parse GPT response as JSON:', e.message);
      return this._emptyMOM('AI response could not be parsed. Please reprocess.');
    }

    const usage = response.usage || {};

    // Normalize owner names against official participant list
    // Also apply title-case to fix any inconsistently cased names in the participants list
    const toTitleCase = (str) =>
      str.replace(/\w\S*/g, (txt) => txt.charAt(0).toUpperCase() + txt.slice(1).toLowerCase());
    const officialNames = Array.isArray(meetingData.participants)
      ? meetingData.participants.map((n) => toTitleCase(n))
      : [];
    const normalizeName = (name) => {
      if (!name || name.trim().length === 0) return 'Team';
      const clean = name.trim().toLowerCase();
      if (clean === 'team' || clean === 'all' || clean === 'everyone') return 'Team';
      for (const official of officialNames) {
        const offLower = official.toLowerCase();
        if (
          clean === offLower ||
          clean.includes(offLower) ||
          offLower.includes(clean) ||
          // Fuzzy: "harmish" matches "Harmish Sejpal"
          offLower.split(' ')[0] === clean ||
          clean.split(' ')[0] === offLower.split(' ')[0]
        ) {
          return official;
        }
      }
      return name.trim();
    };

    return {
      meetingSummary: parsed.meetingSummary || '',
      agenda: Array.isArray(parsed.agenda) ? parsed.agenda : [],
      keyDiscussionPoints: Array.isArray(parsed.keyDiscussionPoints) ? parsed.keyDiscussionPoints : [],
      decisions: Array.isArray(parsed.decisions) ? parsed.decisions : [],
      actionItems: Array.isArray(parsed.actionItems)
        ? parsed.actionItems.map((item) => ({
            task: item.task || '',
            owner: normalizeName(item.owner),
            deadline: item.deadline || 'TBD',
            priority: ['High', 'Medium', 'Low'].includes(item.priority) ? item.priority : 'Medium',
          }))
        : [],
      pendingItems: Array.isArray(parsed.pendingItems) ? parsed.pendingItems : [],
      risks: Array.isArray(parsed.risks) ? parsed.risks : [],
      nextSteps: Array.isArray(parsed.nextSteps) ? parsed.nextSteps : [],
      otherNotes: Array.isArray(parsed.otherNotes) ? parsed.otherNotes : [],
      nextMeeting: {
        date: parsed.nextMeeting?.date || '',
        time: parsed.nextMeeting?.time || '',
      },
      conclusion: parsed.conclusion || '',
      tokenUsage: {
        promptTokens: usage.prompt_tokens || 0,
        completionTokens: usage.completion_tokens || 0,
        totalTokens: usage.total_tokens || 0,
      },
    };
  }

  _emptyMOM(reason) {
    return {
      meetingSummary: reason,
      agenda: [],
      keyDiscussionPoints: [],
      decisions: [],
      actionItems: [],
      pendingItems: [],
      risks: [],
      nextSteps: [],
      nextMeeting: { date: '', time: '' },
      conclusion: '',
      tokenUsage: { promptTokens: 0, completionTokens: 0, totalTokens: 0 },
    };
  }
}

module.exports = OpenAIAIProvider;
