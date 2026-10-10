# Vocabulary and definition review — 10 October 2026

The database is structurally healthy and contains every bundled word, but the
lexical content needs correction. This review records **18 high-priority
corrections**, **185 definition, grammar, wording or raw-reference improvements**,
and **9 pronunciation or traditional-spelling decisions**: **212 entries**
in total. The P2 group includes many valid but incomplete or poorly prioritized
meanings; these are editorial recommendations, not 185 additional factual errors.

The [row-by-row CSV](vocabulary-review-2026-10-10.csv) contains all **4,991 entries**,
their current text, findings, source-comparison results and asset line numbers.
Application code, runtime vocabulary assets and the installed learner database
were not changed. Only these review documents were added.

The follow-up implementation is documented in
[the app improvements report](app-improvements-2026-10-11.md). This review and
its CSV remain a historical snapshot of the values before those corrections.

## Scope and method

- Read every bundled word, its displayed pinyin and primary study definition.
- Compared all entries with pinned snapshots of the original HSK list, the
  import source, the 2012 HSK glossary and the current CC-CEDICT export.
- Checked schema fields, IDs, uniqueness, per-level coverage, tone-mark placement,
  selected dictionary forms, raw definitions and traditional spellings.
- Opened the installed SQLite database with `mode=ro` and `PRAGMA query_only = ON`.
  Compared word/card content and curriculum membership with the assets; ran
  SQLite integrity and foreign-key checks. No learner profiles, API keys, ratings
  or personal records were exported into this report.
- Reviewed the 100 sentence-practice translations and pinyin. Inspected curriculum
  examples for the high-priority word findings. This was **not** a full editorial
  review of all 4,991 curriculum example sentences.
- Re-ran the importer into a temporary file: all generated JSON values exactly
  match the bundled vocabulary. The problems reproduce from the current import
  rules and sources; they are not accidental edits to installed cards.

"No lexical issue identified in this pass" is a review result, not a guarantee
that every possible sense is present or that a native lexicographer has certified
the entry. Several reference datasets share dictionary ancestry, so agreement
among them is not fully independent linguistic validation.

## Coverage and database results

| HSK level | Bundled unique words |
| --- | --- |
| 1 | 150 |
| 2 | 147 |
| 3 | 298 |
| 4 | 598 |
| 5 | 1298 |
| 6 | 2500 |

- 251 current vocabulary decks; 5,020 ordered memberships; 4,991 distinct shared
  cards. The extra memberships are the documented overlapping final decks.
- All 4,991 current curriculum cards match the bundled Hanzi, pinyin, study meaning
  and HSK level. No missing bundled word, duplicate vocabulary ID or duplicate
  simplified headword was found.
- SQLite schema version 17; `integrity_check` returned `ok`; no foreign-key
  violations. The installed database has 5,084 vocabulary card rows and 100
  sentence-practice rows. Historical cards account for the extra word rows.
- 17 archived historical cards differ from the current asset in 28 fields:
  14 pinyin, 8 definition and 6 HSK-level fields. None is a current-curriculum
  mismatch. Some differences are spacing, accepted sandhi or useful longer
  meanings; do not overwrite historical cards indiscriminately.
- Every card's `correct_answer` matches its `english_meaning`. Vocabulary quiz
  options include the designated answer and have no duplicate option strings.
  Sentence-practice cards intentionally have empty quiz-option lists.
- All 100 installed sentence-practice entries match their source asset. No
  material translation error was identified in that sentence-practice pass.

### Reference coverage differences

The bundled entries exactly cover the import source's `old-1`–`old-6` entries.
However, the original `clem109` HSK list has 5,000 rows / 4,993 unique headwords
after seven repeated headwords are deduplicated. It includes two HSK 5 words
missing from the app: **称 — chēng — to weigh; to call**, and
**志愿者 — zhì yuàn zhě — volunteer**. The import source contains both words but
does not assign old-HSK labels to them, so the importer drops them. Resolve this source
coverage discrepancy before calling the list complete relative to that reference.

The 2012 glossary is a different list: 195 bundled words have no exact glossary
headword, 200 glossary headwords are absent from the app, and 316 common words
have different levels. These are source-list differences, not 200 confirmed
missing words in the intended curriculum. Choose and document the target HSK
list before moving levels or adding this entire glossary difference set.

## High-priority corrections

P1 means a clear reading/sense conflict, a misleading lexical definition, or
an invalid tone-mark spelling. Where alternatives are listed, choose the intended
study sense and update the reading, definition and example together.

| Word / HSK | Current reading | Current study definition | Recommended correction | Reason |
| --- | --- | --- | --- | --- |
| 俩 / 4 | liǎng | (colloquial) two (people) | liǎ; two; both | liǎng belongs to 伎俩; the selected raw sense is only a reference to that compound. |
| 干 / 4 | gàn | to concern | gàn; to do; to work | To concern belongs to gān; it conflicts with the intentionally selected gàn form. |
| 丙 / 5 | bǐng | bright | third; label C; third Heavenly Stem | Bright is not the ordinary lexical meaning of this HSK entry. Raw Heavenly-Stem references are also truncated; 甲 and 乙 have additional damaged compound references. |
| 乙 / 5 | yǐ | two | second; label B; second Heavenly Stem | Two confuses an ordinal label with the ordinary cardinal number 二 or 两. Raw Heavenly-Stem references are also truncated; 甲 and 乙 have additional damaged compound references. |
| 甲 / 5 | jiǎ | one | first; label A; first Heavenly Stem | One confuses an ordinal label with the ordinary cardinal number 一. Raw Heavenly-Stem references are also truncated; 甲 and 乙 have additional damaged compound references. |
| 背 / 5 | bèi | carry on one's back | Keep bèi with back; to memorize, or pair carry on one's back with bēi | The study gloss describes bēi while the selected form and raw meanings describe bèi. |
| 哇 / 6 | wa | wow | wā for the exclamation wow, or explain wa as a sentence-final particle | The neutral-tone dictionary form is a particle; the exclamation uses first tone. |
| 大意 / 6 | dà yi | main idea | dà yi; careless, or dà yì; main idea | The neutral-tone form means careless; the study gloss is from the fourth-tone form. |
| 拄 / 6 | zhǔ | post | to lean on a walking stick; to support oneself with | Post turns an action into an unrelated noun and obscures the intended meaning. |
| 挨 / 6 | ái | get close to | ái; to suffer; to endure, or āi; to be next to | Get close to belongs to āi; the selected ái form means suffer or endure. |
| 条理 / 6 | tiáo lǐ | consecutive | logical order; organization | Consecutive is an adjective and does not explain this noun. |
| 欧洲 / 6 | Oū zhōu | Europe | Ōu zhōu | The tone mark in ou belongs on o; Oū has the mark on the wrong vowel. |
| 淋 / 6 | lín | to drain | lín; to drench; to sprinkle | To drain belongs to lìn; the selected lín form has a different sense. |
| 澄清 / 6 | chéng qīng | (of liquid) settle | chéng qīng; to clarify; clear. Use dèng qīng for liquid settling. | The displayed settling gloss belongs to dèng qīng; the selected chéng qīng form means clarify or clear. |
| 生态 / 6 | shēng tài | way of life | ecology; ecological conditions | Way of life is misleading for the modern environmental term. |
| 粉碎 / 6 | fěn suì | to crash | to smash; to crush | To crash is a mistranslation or typo; the selected dictionary sense is to break something into pieces. |
| 起哄 / 6 | qǐ hòng | gather together | to make a noisy disturbance; to heckle | Gather together omits the defining noisy or disruptive behavior. |
| 领先 / 6 | lǐng xiān | leadership | to be ahead; to lead | Leadership describes 领导 or 领导力; 领先 expresses being ahead. |

The [current CC-CEDICT export](https://www.mdbg.net/chinese/dictionary?page=cc-cedict)
supports these reading distinctions; the app's own selected raw dictionary senses
also expose several contradictions. For example, 俩 currently has only the raw
reference to 伎俩, 大意 has only the raw sense "careless", and 背 has the raw
back/memorization senses while its study gloss describes carrying.

## Why the issues recur

### Glosses are selected independently of the chosen reading

In [the importer](../tool/import_hsk_vocabulary.dart), `_selectStudyForm`
(line 150) can intentionally choose a reading from `preferredHsk2Pinyin`.
`_studyMeaning` (line 246) still accepts the glossary's first branch when it
cannot find a matching pronunciation. That produces the mismatches for 干,
背 and 挨. A matching spelling alone is not enough: the definition must come
from the same reading and traditional form.

### First-sense truncation removes important study meanings

`_conciseGloss` (line 276) keeps only the text before the first ASCII semicolon.
It loses home from 家, month from 月, time from 点 and metres from 米. It can
prefer an obscure bound or historical sense over a useful classifier, as with
匹, 幅, 届 and 栋. Fullwidth semicolons are treated differently, and semicolons
inside parentheses can leave damaged text, as in 验收.

Some imported idioms retain only a literal image: 一丝不苟, 举足轻重,
任重道远, 拔苗助长 and 斩钉截铁 need their figurative study meanings.

### The detailed Dictionary view retains upstream damage

[`vocabularyDisplayMeanings`](../lib/database/vocabulary_content.dart) appends
all raw senses after the study meaning. Twelve reviewed words have truncated
Chinese references: 甲, 乙, 丙, 丁, 哈, 高速, 立方, 泰斗, 法人, 得罪,
淡季 and 嫌. Examples include 高速 referring only to 路, 立方 to 米,
and both contract parties in 乙 becoming 方. Repair the actual reference text;
changing the primary gloss alone leaves these defects visible.

### Part-of-speech metadata is not specific to the selected sense

34 entries carry the source's `nr` personal-name tag, including common-word
readings of 东西, 钱, 一起, 夏 and 马. These source tags cover multiple analyses
or readings, while the app displays them as chips for one selected word form.
Review the tags by selected sense and use readable labels. Another 36 entries
have no POS metadata, which is permitted by the present contract and is not
itself a broken definition. The CSV records both cases separately from lexical
findings.

## Pronunciation and spelling decisions

| Word | Current reading / traditional form | Decision to review |
| --- | --- | --- |
| 嘱咐 | zhǔ fù / 囑咐 | Review zhǔ fu as the common current reading |
| 小伙子 | xiǎo huǒ zi / 小伙子 | Compare 小夥子 with the bundled 小伙子 |
| 事迹 | shì jì / 事跡 | Compare 事蹟 with the bundled 事跡 |
| 合伙 | hé huǒ / 合伙 | Compare 合夥 with the bundled 合伙 |
| 吩咐 | fēn fù / 吩咐 | Review fēn fu as the common current reading |
| 大不了 | dà bù liǎo / 大不了 | Review dà bu liǎo as the common current reading |
| 泄露 | xiè lù / 泄露 | Consider xiè lòu as the primary reading and retain xiè lù as an alternative |
| 生锈 | shēng xiù / 生銹 | Compare 生鏽 with the bundled 生銹 |
| 码头 | mǎ tóu / 碼頭 | Review mǎ tou as the common current reading |

The neutral-syllable cases differ between older HSK/glossary sources and the
current dictionary. 泄露 retains an attested alternative, so it is not a clear
pronunciation error. Likewise, **吨 dūn**, **下载 xià zǎi**, **谁 shéi**,
**尴尬 gān gà** and **播种 bō zhǒng** are supported by the downloaded dictionary;
they were not automatically "corrected" based on a more familiar alternative.

Three entries are absent as standalone current dictionary headwords: 打篮球,
系领带 and 纽扣儿. They are legitimate phrases or an erhua form, not missing
Chinese words. The last two intentionally use display-reading overrides, which
explains their non-exact upstream form comparison.

The exhaustive source comparison found 4,989 exact selected source forms and
raw-meaning lists, 4,988 current dictionary headwords, 4,982 matching current
dictionary readings, and 4,978 matching reading/traditional-form combinations.
The nine current-dictionary reading exceptions are the three phrases/erhua
cases, 欧洲, 嘱咐, 吩咐, 大不了, 泄露 and 码头. A matching reading is only a
lookup result: it does not detect wrong-sense matches such as 俩 by itself.

## Quiz definition ambiguity

The structural quiz checks pass, but **24 vocabulary cards have distractor
options that overlap a raw dictionary sense of the same target word** after
lowercasing and removing leading English articles or `to`. This is a candidate
screen, not proof that every overlapping sense is suitable in the intended HSK
context. Clear examples include:

- 实践: designated answer `practice`, distractor `to practice`.
- 人工: designated answer `man-made`, distractor `artificial`.
- 干涉: designated answer `interfere`, distractor `meddle`.
- 规范: designated answer `standard (design or model)`, distractor `standard`.

These options do not reliably distinguish a correct from an incorrect meaning
for an isolated word. Exclude semantic alternatives as distractors or supply a
sentence that selects a single sense. The CSV records the overlap candidates.

| Word | Designated answer | Candidate alternative answers |
| --- | --- | --- |
| 走 | to walk | to run |
| 画 | draw | picture |
| 死 | to die | extremely |
| 否定 | negate | deny |
| 实现 | achieve | to implement |
| 实践 | practice | to practice |
| 形成 | take shape | form |
| 形象 | image | form |
| 热烈 | warm | enthusiastic |
| 状态 | state of affairs | condition |
| 设备 | equipment | facilities |
| 人工 | man-made | artificial |
| 以致 | so that | down to |
| 嫌 | to dislike | suspicion |
| 完毕 | finish | complete |
| 干涉 | interfere | meddle |
| 弊病 | malady | malpractice |
| 掩饰 | conceal a fault | conceal |
| 纯粹 | purely | pure |
| 规范 | standard (design or model) | standard |
| 赞扬 | to praise | to approve of |
| 防御 | defense | to defend |
| 飘扬 | wave in the wind | fly |
| 高潮 | high tide | upsurge |

## Related example findings

Targeted example inspection found additional problems attached to flagged words:

- **俩**: the original example 我们俩是很好的朋友 has `liǎng`; use the colloquial
  `liǎ` reading for its "two of us" meaning.
- **背**: the sentence about carrying a heavy schoolbag transcribes the verb as
  `bèi`; it needs `bēi`. Its 得 must also be checked as `děi` in this obligation
  context. Preserve the original transcription as provenance and record the
  correction or replacement through the established example-override workflow.
- **大意**: the example describes carelessness but transcribes `dàyì`; use
  the neutral-final-syllable careless reading consistently.
- **淋**: the selected example contains the character only inside 冰激淋
  (ice cream). It does not illustrate the standalone word's drenching sense.
- **哇**: its example already uses `wā` for the exclamation, contradicting
  the stored word reading `wa`.
- **甲**: the example contains 甲板 (deck), which does not teach the proposed
  A/first label sense. Select an example for the intended standalone sense.

These are reasons to audit example sense and word boundaries when implementing
the word corrections. The generator's substring test and permissive neutral-tone
matching do not establish that an example teaches the intended sense.

## Definition and wording recommendations

P2 includes correct but incomplete senses, inappropriate primary senses,
grammar explanations, damaged references and English wording. The recommended
glosses are editorial proposals rather than full dictionary replacements.

| Word / HSK | Current study definition | Recommended wording / action | Reason |
| --- | --- | --- | --- |
| 上午 / 1 | late morning (before noon) | morning; before noon | Late unnecessarily restricts a word that covers the morning before noon. |
| 下 / 1 | fall | down; below; next | Fall alone hides the elementary directional and relative senses. |
| 不 / 1 | no | not; no | Not is the essential negative-prefix sense and should accompany no. |
| 了 / 1 | indicates a completed or finished action | particle marking a completed action or a change of state | The current explanation covers only the completion use and can be mistaken for a past-tense marker. |
| 呢 / 1 | indicates a question | question or topic particle; what about ...? | Indicates a question is too general to distinguish it from 吗. |
| 块 / 1 | lump | piece; yuan in everyday prices | Lump alone misses the common money and classifier uses taught at this level. |
| 字 / 1 | letter | written character; letter | Character is the useful primary sense for a Mandarin learner. |
| 家 / 1 | family | family; home | The primary gloss loses home, an essential use in 回家 and 在家. |
| 想 / 1 | think | to think; to want; to miss | Think alone misses common desire and missing-someone uses. |
| 日 / 1 | sun | day; date; sun | Sun is valid but day and date are more useful in elementary vocabulary. |
| 月 / 1 | moon | month; moon | Moon alone misses the calendar sense. |
| 没 / 1 | (negative prefix for verbs) have not | not have; did not | The primary explanation omits the possessive negative 没有. |
| 点 / 1 | a dot | o'clock; point; a little | A dot is valid but omits elementary time and quantity uses. |
| 热 / 1 | heat | hot; heat | Hot is the everyday adjective learners need. |
| 认识 / 1 | recognize | to know a person; to recognize | Recognize alone obscures the common acquaintance meaning. |
| 向 / 2 | direction | toward; to | Direction as a noun does not teach the common preposition use. |
| 外 / 2 | outer | outside; outer | Outside is the ordinary location sense. |
| 旅游 / 2 | trip | to travel; tourism | Trip alone hides the action and activity. |
| 比 / 2 | compare | than; to compare | Include the comparative construction rather than only a dictionary verb. |
| 着 / 2 | -ing (indicating action in progress) | particle marking a continuing action or state | Equating it with English -ing is misleading; it also marks enduring states. |
| 离 / 2 | leave | from; away from; to leave | Leave alone omits the distance construction used at this level. |
| 让 / 2 | ask | to let; to allow; to ask someone to | Ask alone obscures the causative and permission uses. |
| 身体 / 2 | health | body; health | Health is valid but omits the concrete body sense. |
| 题 / 2 | topic | question; problem; topic | Topic alone misses the exercise or exam question sense. |
| 位 / 3 | position | polite classifier for people; position | The classifier use is central to elementary Mandarin. |
| 作用 / 3 | action | effect; function; role | Action is too broad to distinguish this word from 行动 or 动作. |
| 使 / 3 | to use | to make; to cause; to use | To use misses the common causative function. |
| 借 / 3 | lend | to borrow; to lend | Mandarin covers both directions; lend alone is incomplete. |
| 包 / 3 | to cover | bag; package; to wrap | To cover alone obscures the common object and wrapping senses. |
| 双 / 3 | two | pair; classifier for paired things | Two alone misses the paired-item classifier use. |
| 复习 / 3 | revise | to review study material; to revise for an exam | Revise can be misread as editing text; specify the study context. |
| 宾馆 / 3 | guesthouse | hotel; guesthouse | Hotel is the common accommodation meaning. |
| 差 / 3 | differ from | poor; not good; to differ | Differ from alone loses the adjective use. |
| 带 / 3 | band | to bring; to take along; belt | Band is valid but omits the essential verb used with objects and people. |
| 成绩 / 3 | achievement | grades; results; achievement | Achievement alone misses the standard school context. |
| 才 / 3 | ability | only; only then; just | Ability is a bound noun sense and hides the common adverb. |
| 把 / 3 | classifier for things with handles | object-marking particle; classifier for handled objects | The classifier gloss is valid but leaves out the central 把 construction. |
| 拿 / 3 | carry in your hand | to take; to hold | Carry in your hand is unnecessarily restrictive. |
| 条 / 3 | strip | classifier for long or narrow things; strip | Strip alone misses its productive classifier use. |
| 楼 / 3 | story | building; floor; storey | Story is an ambiguous English spelling and omits building. |
| 段 / 3 | paragraph | section; stretch; paragraph | Paragraph alone is too narrow. |
| 班 / 3 | team | class; shift; team | Team alone misses school and work uses. |
| 电子 / 3 | electronic | electron; electronic | The noun is important alongside the adjective use. |
| 祝 / 3 | to pray for | to wish someone well | To pray for is a narrow sense and poorly represents birthday and holiday wishes. |
| 米 / 3 | rice | metre; uncooked rice | Rice is valid but omits the measurement unit used at this level. |
| 行李箱 / 3 | trunk | suitcase | Trunk can suggest a car compartment or a large storage chest. |
| 角 / 3 | horn | angle; corner; one tenth of a yuan; horn | Horn alone omits useful geometric and monetary senses. |
| 还是 / 3 | or | or in a question; still | Specify the interrogative choice use rather than a context-free or. |
| 饱 / 3 | eat until full | full after eating | Eat until full makes an adjective sound like an action. |
| 不过 / 4 | only | however; but; only | Only is valid but omits the common connective sense. |
| 专业 / 4 | profession | academic major; specialty; professional | Profession alone misses a university major or area of expertise. |
| 主意 / 4 | plan | idea; suggestion | Plan is broad and overlaps unnecessarily with 计划. |
| 估计 / 4 | appraise | to estimate; to reckon | Appraise suggests assessment of value rather than estimation. |
| 修 / 4 | to decorate | to repair; to study a subject | To decorate is valid but is a poor sole study gloss. |
| 兴奋 / 4 | excitement； be excited | excited; excitement | A fullwidth semicolon bypasses the importer's ASCII-only splitting convention. |
| 千万 / 4 | ten million | ten million; by all means; be sure to | The number alone misses the emphatic adverb. |
| 博士 / 4 | doctor | doctorate; PhD holder | Doctor alone can be mistaken for a medical doctor. |
| 厉害 / 4 | terrible | formidable; impressive; severe | Terrible alone misses positive praise and intensity. |
| 台 / 4 | platform | classifier for machines; platform | Platform alone omits common computer and appliance counting. |
| 场 / 4 | courtyard | venue; classifier for events | Courtyard is a poor sole gloss for this common classifier. |
| 实在 / 4 | honest | really; indeed; honest | Honest alone omits common adverbial uses. |
| 害羞 / 4 | blush | shy; embarrassed | Blush describes a possible reaction rather than the state. |
| 干燥 / 4 | to dry (of paint, cement, etc.) | dry; dryness | To dry paint is a narrow process sense and misses the common adjective. |
| 当 / 4 | should | to serve as; when; at | Should is an uncommon reading-dependent sense for the standalone study word. |
| 指 / 4 | finger | to point at; to refer to; finger | Finger alone omits the central verb uses. |
| 挺 / 4 | straighten up | quite; very; to straighten | Straighten up alone misses the common degree adverb. |
| 收入 / 4 | take in | income; revenue | Take in hides the common financial noun. |
| 无聊 / 4 | nonsense | bored; boring | Nonsense is a poor main explanation for ordinary conversational use. |
| 民族 / 4 | nationality | ethnic group; nationality | Nationality alone can be confused with citizenship, 国籍. |
| 流行 / 4 | spread | popular; fashionable; to circulate | Spread alone misses the common popularity sense. |
| 理发 / 4 | a barber, hairdressing | to get or give a haircut | A barber incorrectly turns the activity into a person. |
| 由 / 4 | follow | by; from; through | Follow hides the common preposition uses. |
| 算 / 4 | to regard as | to calculate; to count as | To regard as is valid but omits arithmetic. |
| 篇 / 4 | sheet | classifier for articles or written pieces | Sheet suggests 张 rather than the written-piece classifier. |
| 联系 / 4 | integrate | to contact; connection | Integrate is an unsuitable primary gloss for keeping in touch. |
| 节约 / 4 | frugal | to save resources; economical | Frugal describes the idea but does not teach the common action. |
| 行 / 4 | walk | okay; to work; to be acceptable; to travel | Walk alone omits the frequent affirmative response. |
| 输 / 4 | to transport | to lose; to transport | To transport is valid but hides the common competition meaning. |
| 适应 / 4 | to suit | to adapt to | To suit overlaps with 适合 and misses adaptation. |
| 遍 / 4 | a time | classifier for a complete repetition | A time does not distinguish 遍 from 次. |
| 顿 / 4 | pause | classifier for meals; pause | Pause alone omits the everyday meal classifier. |
| 一旦 / 5 | in case (something happens) | once; as soon as a condition is met | In case blurs the distinction from 万一. |
| 丁 / 5 | male adult | fourth; label D; fourth Heavenly Stem | Male adult is valid but hides the ordinal-label relationship with 甲乙丙. Raw Heavenly-Stem references are also truncated; 甲 and 乙 have additional damaged compound references. |
| 从事 / 5 | go for | to engage in; to work in | Go for is vague and can imply an unrelated choice or attempt. |
| 便 / 5 | plain | convenient; then | Plain is an obscure primary sense for modern study. |
| 册 / 5 | book | volume; classifier for books | Book alone does not distinguish it from 书. |
| 凭 / 5 | lean against | on the basis of; to rely on | Lean against is valid but loses the important abstract preposition. |
| 则 / 5 | standard | then; but; classifier for written items; rule | Standard alone hides the connective and classifier uses. |
| 功夫 / 5 | kung fu | skill; effort; kung fu | Kung fu alone hides productive everyday skill and effort uses. |
| 匹 / 5 | ordinary person | classifier for horses; bolt of cloth | Ordinary person is a historical bound sense and hides the measure word. |
| 哈 / 5 | exhale | ha; sound of laughter; Restore the complete dictionary cross-reference to 哈士奇. | Exhale misses the familiar laughter or interjection use. A raw dictionary definition has a truncated Hanzi reference; this reaches the Dictionary detail list. |
| 实习 / 5 | to practice | internship; practical training | To practice is too general and overlaps with 练习. |
| 宣传 / 5 | propaganda | publicity; to promote; propaganda | Propaganda alone implies a negative political context that the word does not always require. |
| 届 / 5 | arrive at | classifier for sessions, events or graduating classes | Arrive at is historical and omits the modern classifier use. |
| 幅 / 5 | width of cloth | classifier for pictures or lengths of cloth | Width of cloth omits the productive classifier function. |
| 应聘 / 5 | accept a job offer | to apply for a job | Accept a job offer can imply the applicant has already been selected. |
| 开放 / 5 | (of flowers) to bloom | to open to the public; open-minded; to bloom | Bloom is valid but is a poor sole study gloss. |
| 恐怖 / 5 | afraid | horror; terrifying | Afraid describes the experiencer and loses the terrifying or horror sense. |
| 悠久 / 5 | established | long-standing; having a long history | Established does not convey duration. |
| 所 / 5 | place | classifier for buildings or institutions; place | Place alone omits the classifier and grammatical uses. |
| 打招呼 / 5 | notify | to greet; to say hello | Notify is possible in context but obscures the core social action. |
| 数码 / 5 | numeral | digital; numerical code | Numeral alone omits the common digital-technology sense. |
| 根本 / 5 | root | fundamental; at all, usually in a negative clause | Root alone obscures the common adjective and adverb. |
| 棒 / 5 | stick | excellent; stick | Stick is valid but misses the common praise adjective. |
| 橡皮 / 5 | rubber | eraser; rubber | Rubber alone misses the school stationery item. |
| 欠 / 5 | yawn | to owe; to lack; to yawn | Yawn is valid but hides the common debt sense. |
| 沙滩 / 5 | sand bar | beach; sandy shore | Sand bar is unnecessarily narrow and can describe a different landform. |
| 沟通 / 5 | link | to communicate; to connect | Link alone hides the usual interpersonal communication sense. |
| 烂 / 5 | overcooked | rotten; broken; overcooked | Overcooked is valid but far too narrow as the only gloss. |
| 现象 / 5 | appearance | phenomenon | Appearance is too general and misses the usual abstract noun. |
| 电台 / 5 | transceiver | radio station; transceiver | Transceiver alone hides the broadcast station sense. |
| 立方 / 5 | cube | Restore the complete dictionary cross-reference to 立方米. | A raw dictionary definition has a truncated Hanzi reference; this reaches the Dictionary detail list. |
| 答应 / 5 | to respond | to agree; to promise; to answer | To respond is valid but misses the common agreement sense. |
| 系 / 5 | be | department; system; relationship | Be is a formal copular sense and a poor main explanation. |
| 罐头 / 5 | tin | canned food; can | Tin alone can be mistaken for the metal or an empty container. |
| 聚会 / 5 | hold a meeting | social gathering; get-together | Hold a meeting suggests a formal business meeting. |
| 象棋 / 5 | chess | Chinese chess; xiangqi | Chess without qualification can be mistaken for Western chess. |
| 闻 / 5 | hear | to smell; to hear | Hear is valid but loses the everyday smelling action. |
| 除非 / 5 | only if | unless; only if | Unless makes the standard negative conditional construction clear. |
| 项 / 5 | nape (of the neck) | item; classifier for items; nape | Nape is a historical bound sense and hides modern counting uses. |
| 频道 / 5 | frequency | TV or radio channel | Frequency is closer to 频率 and does not explain the channel noun. |
| 高速 / 5 | high speed | Restore the complete dictionary cross-reference to 高速公路. | A raw dictionary definition has a truncated Hanzi reference; this reaches the Dictionary detail list. |
| 一丝不苟 / 6 | (literally) not one thread loose | meticulous; scrupulous | The literal image omits the meaning of the idiom. |
| 一律 / 6 | same | uniformly; without exception | Same alone obscures the rule applying to every case. |
| 不屑一顾 / 6 | not worth seeing | to dismiss as beneath one's notice | Not worth seeing is a misleading literal interpretation. |
| 主流 / 6 | main stream (of a river) | mainstream; main current | A river-specific gloss misses the usual social or cultural sense. |
| 举足轻重 / 6 | a foot's move sways the balance | to have a decisive influence | The literal image omits the meaning of the idiom. |
| 争气 / 6 | work hard for sth. | to make someone proud through one's efforts | Work hard for something omits the implication of proving one's worth. |
| 以至 / 6 | down to | to the extent that; even | Down to is an incomplete explanation of the connective. |
| 任重道远 / 6 | lit. a heavy load and a long road | to have a heavy responsibility and a long way to go | The literal gloss needs its figurative significance. |
| 保管 / 6 | assure | to keep safe; to take care of | Assure is a contextual secondary use and a poor sole gloss. |
| 全力以赴 / 6 | do at all costs | to devote all one's effort | Do at all costs adds a willingness to pay any price that the idiom does not require. |
| 公告 / 6 | post | public announcement; to announce publicly | Post is too vague to distinguish the official-notice meaning. |
| 公认 / 6 | publicly know (to be) | widely recognized; generally accepted | Publicly know is ungrammatical and obscures recognition. |
| 农历 / 6 | agricultural calendar | traditional Chinese lunar calendar | Agricultural calendar is literal and unclear to learners. |
| 凑合 / 6 | bring together | to make do; to get by | Bring together is valid but omits the frequent colloquial meaning. |
| 分歧 / 6 | difference (of opinion/position） | difference of opinion; disagreement | The English gloss mixes ASCII and fullwidth parentheses. |
| 反动 / 6 | reaction | reactionary; politically regressive | Reaction alone suggests a different ordinary response term. |
| 发火 / 6 | to catch fire | to lose one's temper; to catch fire | The primary gloss hides the very common anger sense. |
| 哎哟 / 6 | hey | ouch; oh dear | Hey does not clearly convey the pain or surprise exclamation. |
| 固执 / 6 | persistent | stubborn; obstinate | Persistent loses the usual negative evaluation. |
| 嫌 / 6 | to dislike | Restore the complete dictionary cross-reference to 嫌犯. | A raw dictionary definition has a truncated Hanzi reference; this reaches the Dictionary detail list. |
| 常务 / 6 | routine | executive; standing, for an organizational role | Routine is vague and hides titles such as 常务委员会. |
| 平原 / 6 | field | plain; flat lowland | Field suggests a smaller cultivated plot. |
| 庸俗 / 6 | filthy | vulgar; commonplace | Filthy is too strong and suggests dirt or obscenity. |
| 得罪 / 6 | offend | Restore the complete dictionary cross-reference to 得罪 with its alternate pronunciation. | A raw dictionary definition has a truncated Hanzi reference; this reaches the Dictionary detail list. Also review dé zui for ordinary offending versus the selected formal dé zuì sense. |
| 心态 / 6 | pyschology | mindset; mental attitude | Pyschology is misspelled and names a discipline rather than a mental attitude. |
| 心血 / 6 | heart and blood | effort and dedication | Heart and blood is a literal image that misses the usual figurative meaning. |
| 慢性 / 6 | slow and patient | chronic; slow-acting | Slow and patient is valid but poorly represents the usual medical adjective. |
| 慷慨 / 6 | vehement | generous; impassioned | Vehement is valid but omits the common generosity sense. |
| 拔苗助长 / 6 | (literally) help shoots grow by pulling them out | to spoil progress by trying to force it | The literal image omits the lesson expressed by the idiom. |
| 拘留 / 6 | detain (a prison) | to detain someone; detention | Detain a prison makes the building the object instead of the person. |
| 效益 / 6 | benefit；results | benefit; effectiveness | A fullwidth semicolon bypasses the importer's ASCII-only splitting convention. |
| 敷衍 / 6 | to elaborate (on a theme) | to do perfunctorily; to fob someone off | To elaborate is a historical sense and misses the usual negative use. |
| 斩钉截铁 / 6 | to chop the nail and slice the iron (idiom) | resolute; unequivocal | The literal image omits the meaning of the idiom. |
| 时差 / 6 | jetlag | time difference; jet lag | Jetlag alone omits the difference between time zones. |
| 栋 / 6 | roof beam | classifier for buildings | Roof beam is an old sense and hides the modern measure word. |
| 株 / 6 | stem | classifier for plants; plant | Stem alone misses the productive classifier use. |
| 沾光 / 6 | bask in the light | to benefit through an association with someone | Bask in the light is literal and does not explain the figurative use. |
| 法人 / 6 | legal entity (i.e., a corporation) | Restore the complete dictionary cross-reference to 自然人. | A raw dictionary definition has a truncated Hanzi reference; this reaches the Dictionary detail list. |
| 泰斗 / 6 | leading scholar of his time | Restore the complete dictionary cross-reference to 泰山北斗. | A raw dictionary definition has a truncated Hanzi reference; this reaches the Dictionary detail list. |
| 淡季 / 6 | off season | Restore the complete dictionary cross-reference to 旺季. | A raw dictionary definition has a truncated Hanzi reference; this reaches the Dictionary detail list. |
| 漂浮 / 6 | superficial | to float; to drift | Superficial is a figurative secondary sense and a poor sole gloss. |
| 生机 / 6 | reprieve from death | vitality; a chance of survival | Reprieve from death is narrow and obscures the common vitality sense. |
| 疲惫 / 6 | beaten | exhausted; worn out | Beaten can suggest a defeat rather than physical or mental exhaustion. |
| 盲目 / 6 | blindness | blindly; without thinking | Blindness loses the common figurative behavior sense. |
| 神仙 / 6 | fig. lighthearted person | immortal; supernatural being | A figurative lighthearted person is an unsuitable sole main gloss. |
| 私自 / 6 | private | without permission; on one's own authority | Private omits the unauthorized-action implication. |
| 素食 / 6 | vegetables | vegetarian food; vegetarian diet | Vegetables alone is too narrow and omits the diet or food category. |
| 统筹兼顾 / 6 | take every aspects into consideration through plan and preparation | to plan as a whole while considering all interests | The current English has a grammar error and is unnecessarily awkward. |
| 聋哑 / 6 | deaf and dumb | deaf and unable to speak | Deaf and dumb is dated and can misleadingly suggest lack of intelligence. |
| 胸怀 / 6 | think about | breadth of mind; aspirations; to cherish | Think about alone is too vague to convey the characteristic mental or emotional sense. |
| 落实 / 6 | workable | to implement; to put into effect | Workable is valid but omits the central action meaning. |
| 蒙 / 6 | drizzle | Review 蒙 (cover; receive) versus the selected 濛 (mist; drizzle), both méng | The selected traditional form is 濛 and its meanings are only drizzle or mist; the common 蒙 sense needs a deliberate traditional-form choice. |
| 表彰 / 6 | cite (in dispatches) | to commend publicly | Cite in dispatches is a narrow dated military gloss. |
| 要命 / 6 | cause somebody's death | terrible; unbearable; life-threatening | Cause somebody's death is valid but omits frequent figurative uses. |
| 赞叹 / 6 | sigh or grasp in admiration | to exclaim in admiration | Grasp is a typo for gasp; a clearer paraphrase avoids the problem. |
| 过渡 / 6 | to cross a river by ferry | transition; to move from one stage to another | The ferry gloss is valid but obscures the usual abstract sense. |
| 部署 / 6 | dispose | to deploy; to arrange | Dispose is dated and can be mistaken for throwing something away. |
| 附和 / 6 | repeat an agreement | to echo someone's opinion; to agree along with | Repeat an agreement is unnatural and unclear. |
| 陈述 / 6 | allegation | to state; statement | Allegation implies a disputed accusation, which this neutral word does not require. |
| 随手 / 6 | convenient | as one does something; casually; readily | Convenient alone loses the manner-of-action use. |
| 须知 / 6 | prerequisites | instructions; things one should know | Prerequisites is too narrow for posted notices and guidance. |
| 验收 / 6 | inspect and then accept (i.e. received goods | to inspect and accept a delivery or completed work | The first-semicolon truncation leaves an unmatched parenthesis and drops part of the explanation. |
| 高尚 / 6 | nobly | noble; admirable | Nobly is an adverb and does not explain the adjective. |

## Applying corrections safely

1. Add reviewed reading, traditional-form, primary-gloss and raw-meaning
   overrides to the import workflow. Require a definition branch to match the
   selected reading; otherwise use that selected form's substantive senses.
   Prefer one or two concise useful meanings over blind first-semicolon slicing.
2. Resolve the two missing source-list words separately, with stable IDs and
   curriculum coverage, after choosing the intended HSK reference.
3. Regenerate the vocabulary and affected examples through their source tools
   and explicit overrides. Keep existing example attribution intact.
4. Add an explicit, transactional content update for installed bundled cards.
   Existing `hsk_vocabulary_content_v2` and `bundled_hsk_curriculum_v1` markers
   already prevent ordinary startup from reinstalling edited definitions.
   Update definitions, readings, correct answers and affected distractors in
   place; preserve card IDs, progress, reviews, memberships and resumable sessions.
   Protect custom cards and apply the update consistently after backup restore.
5. Add regression coverage for the P1 pairs, ordinal labels, malformed
   parenthetical glosses and source coverage, plus upgrade/idempotence tests.
   Validate example sense rather than only target-character containment.
   Add a check for equivalent or valid alternative quiz options as well.

The current 17-word ambiguity test checks useful earlier corrections but does
not include these P1 failures. Its expected primary meanings for 台 and 钟
also show why a passing dataset test cannot substitute for editorial review.

## Checks run

Flutter **3.44.4**, Dart **3.12.2**. All **27 focused tests passed**:

```sh
flutter test test/vocabulary_dataset_test.dart \
  test/vocabulary_content_test.dart \
  test/vocabulary_lesson_dataset_test.dart \
  test/vocabulary_lesson_content_test.dart \
  test/bundled_vocabulary_repository_test.dart \
  test/bundled_lesson_rewrite_test.dart
```

The importer ran successfully against the pinned source/glossary snapshots and
reproduced all 4,991 JSON entries exactly. SQLite integrity, foreign keys,
current curriculum memberships, card-answer fields, vocabulary quiz options and
sentence-asset comparisons passed. Report/CSV counts and IDs were cross-checked.
No full application suite, analyzer or platform build was needed for these
documentation-only artifacts; no application code was edited.

## Source snapshots

- [Import source](https://github.com/drkameleon/complete-hsk-vocabulary/tree/7ac65bf1a6387d35f1ade478906172a19311c7f9),
  commit `7ac65bf1a6387d35f1ade478906172a19311c7f9`, `complete.json`.
- [Original HSK reference](https://github.com/clem109/hsk-vocabulary/tree/f3dc9d12ae00d04fa3676b0bd4c43cd58de2c264/hsk-vocab-json),
  commit `f3dc9d12ae00d04fa3676b0bd4c43cd58de2c264`, six level JSON files.
- [2012 glossary](https://github.com/glxxyz/hskhsk.com/tree/8a6f229c699e2fd7ac8708156c55c3afb2be7e1f/data/lists),
  commit `8a6f229c699e2fd7ac8708156c55c3afb2be7e1f`, six
  `HSK Official With Definitions 2012 L1.txt`–`L6.txt` files. Frequency-order
  duplicates were not inputs to the importer.
- [CC-CEDICT](https://www.mdbg.net/chinese/dictionary?page=cc-cedict), export
  header date **2026-10-09T09:12:50Z**, **125,244 entries**, downloaded on the
  review date. Gzip SHA-256:
  `dd2307775fd21f5d350e6cb0e6a946bfe2eaedd79bb9ce524a67e7fccddf6a8f`.

Reviewed checkout: `5add4df` (`1.0.0-beta.7+7`). Asset SHA-256 values:

| Asset | SHA-256 |
| --- | --- |
| assets/data/hsk_vocabulary.json | 8e39efdbf47b7faaec28791296bcafc529266e4411b933696550d785d13ee472 |
| assets/data/vocabulary_lessons.json | 41771825fa98182b42a1b6686171fc620254c5fc8ce287ebeb1ede658dd1a510 |
| assets/data/sentence_practice.json | 70c93b0114513b7772bd87c466be68c59b9126c6aa98a4e8ca2670fd5139e769 |

The report summarizes source evidence and editorial judgments; the CSV retains
the app's existing study text rather than distributing the downloaded dictionary.
