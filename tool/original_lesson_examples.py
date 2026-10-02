"""Original study examples used only when no suitable Tatoeba pair is available.

Frames have explicit semantic groups rather than applying arbitrary verb objects.
Sentence readings are assembled from the bundled word readings and an explicit
supporting lexicon; unknown syllables fail regeneration instead of being guessed.
"""
import re
from pathlib import Path
import json

# (words, Chinese frame, English frame). {meaning} uses the vocabulary gloss.
GROUPS = [
('售货员 嘉宾 乘务员 保姆 元首 原告 参谋 司令 徒弟 泰斗 董事长 股东 下属', '这位{word}很有经验。', 'This {meaning} is very experienced.'),
('伯母 公婆 嫂子 岳父 华裔 华侨', '我们今天去看望{word}。', 'We are visiting {meaning} today.'),
('发票 登机牌 传单 刊物 文凭 标本 样品 棍棒 碧玉 稿件 请柬 调料 螺丝钉 附件 纽扣儿 墨水儿', '请把{word}放在桌上。', 'Please put the {meaning} on the table.'),
('桔子 佳肴 糖葫芦 馅儿', '我想尝尝这里的{word}。', 'I would like to try the {meaning} here.'),
('京剧 武术 气功', '她每周都练习{word}。', 'She practices {meaning} every week.'),
('传记 连续剧 武侠', '我最近很喜欢看{word}。', 'I have enjoyed watching or reading {meaning} lately.'),
('专科 专长 专题 世界观 原理 宏观 微观 生理', '今天的课程介绍了{word}。', 'Today’s lesson introduced {meaning}.'),
('池子 亭子 园林 港湾 盆地 立交桥 铜矿 公安局 边疆', '他们正在参观这处{word}。', 'They are visiting this {meaning}.'),
('鞭炮', '春节的时候，我们听到了{word}的声音。', 'During the Spring Festival, we heard firecrackers.'),
('压岁钱 红包', '孩子们收到了{word}，非常开心。', 'The children received {meaning} and were very happy.'),
('国庆节 重阳节 正月', '{word}的时候，我们会和家人团聚。', 'During {meaning}, we will get together with our family.'),
('四肢 胸膛 口腔 颈椎', '医生仔细检查了他的{word}。', 'The doctor carefully examined his {meaning}.'),
('化肥 稻谷 畜牧 水利', '这位农民向我们介绍了{word}。', 'This farmer told us about {meaning}.'),
('导弹 舰艇 船舶 轮船', '博物馆里有{word}的模型。', 'There is a model of a {meaning} in the museum.'),
('目录 提纲 备忘录 纪要 草案 章程 条款 纲领 序言', '请仔细阅读这份{word}。', 'Please read this {meaning} carefully.'),
('分量 比例 数目 数额 比重 百分点 误差 频率 方位 重心', '我们需要准确计算{word}。', 'We need to calculate the {meaning} accurately.'),
('偏差 隐患 缺口 差距 弊病 弊端 纠纷 隔阂 周折 变故 悬念 恩怨', '我们正在讨论如何解决{word}的问题。', 'We are discussing how to deal with the problem of {meaning}.'),
('品德 上进心 志气 气魄 魄力 风度 正气 威望 宗旨', '他很重视{word}。', 'He attaches great importance to {meaning}.'),
('规格 标记 指标 标本 商标 称号 籍贯', '请确认{word}是否正确。', 'Please check whether the {meaning} is correct.'),
('债券 股份 经费 分红', '这份报告介绍了{word}的情况。', 'This report describes the situation regarding {meaning}.'),
('年度 近代 历代 诞辰', '这本书详细记录了{word}的情况。', 'This book gives a detailed account of {meaning}.'),
('斑纹 颗粒 泡沫 结晶 包袱 杠杆 秤 筐 羽绒服 雕塑', '我仔细观察了这个{word}。', 'I examined this {meaning} carefully.'),
('东道主', '作为{word}，我们要照顾好客人。', 'As hosts, we must take good care of our guests.'),
('主流', '这条河的{word}流向南方。', 'The main stream of this river flows south.'),
('单元 步骤 名额 名次 栏目 片断 行列 职务 职能 题材 造型 阵容', '请介绍一下这个{word}。', 'Please tell us about this {meaning}.'),
('亚军 季军 胜负 预赛', '大家都很关心{word}的情况。', 'Everyone is interested in the {meaning}.'),
('谜语', '这个{word}很有趣，你能猜出来吗？', 'This riddle is interesting. Can you solve it?'),
('门诊', '今天的{word}很忙。', 'The outpatient clinic is very busy today.'),
('蛋白质', '这种食物含有丰富的{word}。', 'This food is rich in protein.'),
('生机', '春天来了，花园充满了{word}。', 'Spring has come, and the garden is full of vitality.'),
('凹凸', '这块石头表面{word}不平。', 'The surface of this stone is uneven.'),
('利害', '我们要仔细考虑这件事的{word}关系。', 'We must carefully consider the interests involved in this matter.'),
('经纬', '织布时，{word}交织在一起。', 'In weaving, the warp and weft interlace.'),
('雌雄', '这种动物很容易分辨{word}。', 'It is easy to distinguish males and females of this species.'),
('座右铭', '他的{word}是坚持学习。', 'His motto is to keep learning.'),
('公证', '这份文件需要办理{word}。', 'This document needs notarization.'),
('奖赏', '努力工作的人应该得到{word}。', 'People who work hard should receive a reward.'),
('处分', '违反规定的人受到了{word}。', 'Those who broke the rules were disciplined.'),
('俘虏', '战争结束后，{word}回到了家乡。', 'After the war, the prisoners returned home.'),
('公告', '请阅读门口的{word}。', 'Please read the announcement at the entrance.'),
('作息', '规律的{word}有利于健康。', 'A regular work and rest schedule is good for your health.'),
('胸怀', '他有宽广的{word}。', 'He is broad-minded.'),
('屑 渣', '请把桌上的{word}清理干净。', 'Please clear the {meaning} off the table.'),
('模范', '她是我们学习的{word}。', 'She is a model for us to learn from.'),
('福气', '能和家人一起生活是一种{word}。', 'It is a blessing to live with one’s family.'),
('风光', '这里的{word}非常美丽。', 'The scenery here is beautiful.'),
('国防 通讯 治安 内幕 内涵 动态 全局 公务 功劳 劲头 惯例 意向 成效 心得 心血 方针 智商 机遇 权益 来历 格局 案例 气势 派别 焦点 现状 眼色 神态 荧屏 见闻 贬义 面貌 性质 纪律 正负 觉悟 招投标', '这份报告详细介绍了{word}。', 'This report describes {meaning} in detail.'),
]

# Verb frames group compatible objects. Explicit English verb glosses are below.
VERBS = [
('积累', '经验', 'experience'), ('预习', '课文', 'the lesson'),
('推广 运用 参照 借鉴', '这种方法', 'this method'),
('维护', '自己的权益', 'our rights'), ('缩小', '差距', 'the gap'),
('制订 拟定 部署', '新的计划', 'a new plan'), ('列举', '几个例子', 'a few examples'),
('倡导', '健康的生活方式', 'a healthy lifestyle'), ('兑现', '自己的承诺', 'our promises'),
('扩充', '自己的知识', 'our knowledge'), ('权衡', '各种选择', 'the options'),
('杜绝', '这种行为', 'this behavior'), ('鉴别 辨认', '不同的材料', 'different materials'),
('采购', '需要的设备', 'the equipment we need'), ('培育 饲养', '这些动物', 'these animals'),
('安置 慰问', '这些老人', 'these elderly people'), ('挽救', '他的生命', 'his life'),
('批判', '这种观点', 'this view'), ('贯彻 落实', '新的规定', 'the new rules'),
('注重', '学习的质量', 'the quality of our learning'), ('钻研', '这个问题', 'this problem'),
('挖掘', '自己的潜力', 'our potential'), ('考核', '员工的能力', 'the employees’ abilities'),
('征收', '相关的税款', 'the relevant taxes'), ('缴纳', '相关的费用', 'the required fees'),
('批发', '这些商品', 'these goods'), ('浸泡', '这些豆子', 'these beans'),
('灌溉', '这些农田', 'these fields'), ('防守', '这个位置', 'this position'),
('阻拦', '车辆进入', 'vehicles from entering'), ('阻挠', '计划的实施', 'the plan’s implementation'),
('号召 鼓动', '大家一起参加', 'everyone to join in'), ('团圆 联欢', '', ''),
('衔接', '前后的内容', 'the preceding and following content'),
('调解', '双方的矛盾', 'the conflict between the two sides'), ('治理', '污染问题', 'the pollution problem'),
('表彰', '优秀的员工', 'outstanding employees'), ('请示', '下一步的安排', 'instructions for the next step'),
('表态', '', ''), ('塑造', '良好的形象', 'a good image'), ('展现', '自己的才能', 'our talents'),
('施展', '自己的才能', 'our talents'), ('发挥 发扬', '自己的优势', 'our strengths'),
('主办 承办', '这次会议', 'this conference'), ('报告 汇报', '工作的进展', 'the progress of our work'),
('筛选', '合适的人选', 'suitable candidates'), ('盖章', '', ''), ('托运', '这些行李', 'this baggage'),
('登录', '自己的账户', 'our accounts'), ('开采', '这里的矿产', 'the minerals here'),
('致辞', '', ''), ('请教', '老师', 'the teacher'), ('构思 起草', '新的方案', 'a new proposal'),
('调动', '大家的积极性', 'everyone’s enthusiasm'), ('勉励 督促', '学生认真学习', 'the students to study seriously'),
('提拔', '优秀的人才', 'talented people'), ('请假', '', ''), ('结算', '这个月的费用', 'this month’s costs'),
('赠送', '一些礼物', 'some gifts'), ('陈列', '这些作品', 'these works'),
('领悟', '其中的道理', 'the underlying principle'), ('开阔', '自己的眼界', 'our horizons'),
('谅解', '对方的困难', 'the other person’s difficulties'), ('培育', '新的品种', 'new varieties'),
('慰问', '受灾的家庭', 'families affected by the disaster'), ('宣扬', '这种思想', 'this idea'),
('调剂', '生活', 'our daily routines'), ('防治', '这种疾病', 'this disease'),
('反射', '光线', 'light'), ('分解 合成', '这种物质', 'this substance'),
('共计', '二十人', 'twenty people'), ('配合', '医生的检查', 'the doctor’s examination'),
('雕刻 铸造', '这些零件', 'these parts'), ('转让', '这项技术', 'this technology'),
('揭发', '违法的行为', 'illegal behavior'), ('谢绝', '不必要的邀请', 'unnecessary invitations'),
('拥护', '这个决定', 'this decision'), ('取缔', '非法的组织', 'illegal organizations'),
('占有', '这些资源', 'these resources'), ('查获', '这些非法物品', 'these illegal goods'),
('整顿', '市场秩序', 'order in the market'), ('保留', '这些资料', 'these materials'),
('表决', '这项提议', 'this proposal'), ('颁布', '新的法律', 'new laws'),
('分红', '', ''), ('勘探', '这里的资源', 'the resources here'),
('监督', '工程的质量', 'the quality of the project'), ('款待', '远方的客人', 'guests from far away'),
('谋求', '更好的发展', 'better development'), ('攻克', '这个难题', 'this difficult problem'),
('调和', '双方的利益', 'the interests of both sides'), ('操练', '这些动作', 'these movements'),
('熏陶', '孩子的心灵', 'children’s minds'), ('照应', '前面的内容', 'the earlier content'),
('灌溉', '农田', 'the farmland'), ('防疫', '', ''),
]

SPECIAL = '''
填空|请根据课文内容填空。|Please fill in the blanks using the lesson text.
打针|护士正在给病人打针。|The nurse is giving the patient an injection.
干活儿|他们每天都在地里干活儿。|They work in the fields every day.
敬爱|我们都很敬爱这位老师。|We all respect and love this teacher.
转告|请把这个消息转告给她。|Please pass this message on to her.
体现|这件事体现了他的责任感。|This incident reflects his sense of responsibility.
嘱咐|妈妈嘱咐我早点回家。|Mother told me to come home early.
结账|吃完饭后，我们一起去结账。|After the meal, we went to pay the bill.
俩|我们俩是很好的朋友。|The two of us are good friends.
若干|报告提出了若干建议。|The report put forward several suggestions.
丙|甲、乙、丙是三个不同的小组。|A, B, and C are three different groups.
何必|你何必为这点小事生气呢？|Why get angry over such a small matter?
使劲儿|他使劲儿推开了那扇门。|He pushed the door open with all his strength.
初级|她正在参加初级汉语课程。|She is taking an elementary Chinese course.
常务|常务会议每周举行一次。|The regular meeting is held once a week.
特定|这种方法只适用于特定的情况。|This method applies only in specific circumstances.
现成|我们可以使用现成的材料。|We can use ready-made materials.
资深|这位资深记者很有经验。|This senior reporter is very experienced.
首要|安全是我们的首要任务。|Safety is our top priority.
吃亏|不懂规则的人容易吃亏。|People who do not know the rules can suffer losses.
闭塞|这个村子交通闭塞。|This village has poor transport connections.
隐蔽|这个入口很隐蔽。|This entrance is well concealed.
唉|唉，今天又错过了公共汽车。|Oh dear, I missed the bus again today.
刹那|就在那一刹那，她明白了。|At that very moment, she understood.
坚决|我们坚决反对浪费。|We firmly oppose waste.
壮烈|人们纪念那些壮烈牺牲的英雄。|People commemorate the heroes who died bravely.
简要|请简要介绍一下你的计划。|Please briefly explain your plan.
郑重|他向大家郑重道歉。|He formally apologized to everyone.
委屈|她觉得自己受了委屈。|She felt that she had been treated unfairly.
幸亏|幸亏你提醒了我。|Luckily, you reminded me.
格外|今天的花格外美丽。|The flowers are especially beautiful today.
连忙|听到敲门声，她连忙去开门。|Hearing the knock, she hurried to open the door.
一度|他一度想放弃这个计划。|For a while, he wanted to give up this plan.
不愧|她不愧是一位优秀的老师。|She truly deserves to be called an excellent teacher.
不料|我带了雨伞，不料天晴了。|I brought an umbrella, but unexpectedly it cleared up.
专程|他专程来这里看望老师。|He made a special trip here to visit his teacher.
依次|请大家依次进入教室。|Please enter the classroom one by one.
偏偏|我想早点出门，偏偏下雨了。|I wanted to leave early, but it happened to rain.
势必|浪费时间势必影响学习。|Wasting time is bound to affect learning.
反倒|休息以后，他反倒觉得更累了。|After resting, he actually felt even more tired.
大肆|他们大肆破坏森林。|They recklessly destroyed the forest.
屡次|他屡次帮助我们解决困难。|He has repeatedly helped us overcome difficulties.
恨不得|我恨不得马上见到家人。|I wish I could see my family right away.
成心|他不是成心让你生气的。|He did not deliberately try to make you angry.
擅自|请不要擅自改变计划。|Please do not change the plan without permission.
暂且|我们暂且不讨论这个问题。|We will leave this question aside for now.
未免|这样要求孩子未免太严格了。|It is a little too strict to expect this of a child.
毅然|她毅然决定继续学习。|She resolutely decided to keep studying.
略微|气温略微下降了。|The temperature dropped slightly.
索性|既然下雨了，我们索性留在家里。|Since it is raining, we might as well stay home.
逐年|这里的游客数量逐年增加。|The number of visitors here increases every year.
一贯|他一贯认真负责。|He has always been conscientious and responsible.
初步|我们已经有了初步的计划。|We already have a preliminary plan.
原先|原先的计划需要改变。|The original plan needs to change.
就近|你可以就近找一家医院。|You can find a nearby hospital.
常年|这条河常年都有水。|This river has water all year round.
慌忙|他慌忙跑出了教室。|He hurried out of the classroom.
踊跃|同学们踊跃参加活动。|The students eagerly took part in the activity.
摄氏度|今天的气温是二十摄氏度。|The temperature today is twenty degrees Celsius.
株|我们在花园里种了三株树。|We planted three trees in the garden.
毫米|这块木板厚十毫米。|This board is ten millimeters thick.
本着|我们本着公平的原则处理这件事。|We are handling this matter according to the principle of fairness.
鉴于|鉴于天气不好，我们取消了活动。|In view of the bad weather, we canceled the activity.
比方|我给你打个比方。|Let me give you an example.
沉淀|水里的泥沙慢慢沉淀下来。|The sediment in the water slowly settled.
甭|这件事你甭担心。|You need not worry about this.
缓和|他们的关系逐渐缓和了。|Their relationship gradually improved.
跟前|孩子站在妈妈跟前。|The child stood in front of his mother.
辩证|我们应该辩证地看待这个问题。|We should consider both sides of this issue.
连年|这里连年丰收。|This area has had good harvests for several years running.
配套|这套设备的配套设施很完善。|The supporting facilities for this equipment are comprehensive.
间接|这件事间接影响了我们的生活。|This incident indirectly affected our lives.
一丝不苟|他检查文件时一丝不苟。|He checks documents meticulously.
一举两得|骑车上班既省钱又锻炼身体，真是一举两得。|Cycling to work saves money and provides exercise: two benefits at once.
一如既往|她一如既往地支持我们。|She supports us just as she always has.
不相上下|这两位选手的水平不相上下。|These two competitors are evenly matched.
东张西望|上课时不要东张西望。|Do not look around distractedly during class.
为首|他们组成了一个以她为首的小组。|They formed a group headed by her.
举世闻名|这是一座举世闻名的城市。|This is a world-famous city.
举足轻重|她在团队中起着举足轻重的作用。|She plays a crucial role in the team.
予以|对合理的建议，我们应该予以支持。|We should give our support to reasonable suggestions.
亏待|他从来没有亏待过朋友。|He has never treated his friends unfairly.
任重道远|保护环境任重道远。|Protecting the environment is a demanding long-term task.
优胜劣汰|市场竞争中常有优胜劣汰。|Competition in the market often rewards the strongest and eliminates the weakest.
伺候|她每天耐心伺候生病的老人。|She patiently cares for the sick elderly person every day.
作废|这张旧票已经作废了。|This old ticket is no longer valid.
供不应求|这种商品现在供不应求。|Demand for this product now exceeds supply.
做东|今天由我做东，请大家吃饭。|I will be the host today and treat everyone to a meal.
做主|这件事我不能替你做主。|I cannot make this decision for you.
停泊|那艘船停泊在港口。|That ship is anchored in the harbor.
兢兢业业|他工作一直兢兢业业。|He has always worked conscientiously.
再接再厉|取得进步以后，我们还要再接再厉。|After making progress, we must keep up our efforts.
冒充|他冒充医生骗取信任。|He pretended to be a doctor to gain people's trust.
凑合|今天的午饭就简单凑合一下吧。|Let us make do with a simple lunch today.
刻不容缓|修理这座桥已经刻不容缓。|Repairing this bridge cannot wait any longer.
力图|她力图找到更好的办法。|She is trying hard to find a better solution.
勇于|我们应该勇于承认错误。|We should have the courage to admit mistakes.
博大精深|中国文化博大精深。|Chinese culture is broad and profound.
叹气|他看着账单叹气。|He sighed as he looked at the bill.
各抒己见|讨论时，大家可以各抒己见。|During the discussion, everyone can express their own views.
名副其实|她是一位名副其实的专家。|She truly is an expert in every sense.
呼啸|寒风在窗外呼啸。|The cold wind whistled outside the window.
哆嗦|他冷得直哆嗦。|He was shivering from the cold.
喘气|跑完步后，他不停地喘气。|After running, he kept panting.
奠定|认真学习为将来奠定了基础。|Studying seriously lays the foundation for the future.
安居乐业|人们希望能够安居乐业。|People hope to live in peace and work happily.
实事求是|研究问题要实事求是。|We must be practical and factual when studying a problem.
家喻户晓|这个故事已经家喻户晓了。|This story is already known in every household.
层出不穷|新的问题层出不穷。|New problems keep arising.
巴结|他不愿意巴结别人。|He is unwilling to flatter others to gain favors.
并存|机遇和挑战往往并存。|Opportunities and challenges often coexist.
得不偿失|为了省钱而损害健康，实在得不偿失。|Saving money at the cost of health is not worth it.
微不足道|和大家的努力相比，我的贡献微不足道。|Compared with everyone's efforts, my contribution is negligible.
心疼|看到孩子受伤，妈妈很心疼。|Seeing her child hurt caused the mother great distress.
怠慢|请原谅我们招待不周，怠慢了客人。|Please forgive our poor hospitality toward our guests.
急于求成|学习语言不能急于求成。|You cannot expect instant success when learning a language.
急功近利|做研究不能急功近利。|Research must not focus on quick gains.
恍然大悟|听完解释，他恍然大悟。|After hearing the explanation, he suddenly understood.
惊动|请小声一点，别惊动孩子。|Please be quiet so that you do not disturb the child.
惦记|她一直惦记着远方的家人。|She keeps thinking with concern about her family far away.
憋|他把想说的话憋在心里。|He kept the words he wanted to say bottled up inside.
打官司|他们为了这件事打官司。|They went to court over this matter.
把关|我们请专家为产品质量把关。|We asked an expert to oversee product quality.
抹杀|不能抹杀他的贡献。|His contribution must not be dismissed.
抽空|请抽空给家人打个电话。|Please find time to call your family.
拽|孩子拽着妈妈的衣服。|The child was tugging at his mother's clothes.
挎|她挎着一个小包走进教室。|She walked into the classroom with a small bag on her arm.
挑拨|不要挑拨朋友之间的关系。|Do not sow discord between friends.
挥霍|他不应该挥霍父母的钱。|He should not squander his parents' money.
振兴|他们希望振兴家乡的经济。|They hope to revitalize their hometown's economy.
捎|请帮我捎一封信给她。|Please take a letter to her for me.
捣乱|请安静，不要在课堂上捣乱。|Please be quiet and do not disrupt the class.
据悉|据悉，新的公园下个月开放。|According to reports, the new park opens next month.
搀|她搀着老人走过马路。|She helped the elderly person across the road by the arm.
搂|妈妈轻轻搂着孩子。|The mother gently held her child in her arms.
攒|他正在攒钱买自行车。|He is saving money to buy a bicycle.
新陈代谢|运动有助于促进新陈代谢。|Exercise helps promote metabolism.
施加|不要给孩子施加太大的压力。|Do not put too much pressure on children.
无动于衷|听到这个消息，他仍然无动于衷。|He remained unmoved after hearing the news.
无可奈何|面对这个结果，她感到无可奈何。|Faced with this outcome, she felt helpless.
无精打采|他今天看起来无精打采。|He looks listless today.
日新月异|科学技术的发展日新月异。|Science and technology change rapidly every day.
服气|她做得这么好，我很服气。|She did such a good job that I am convinced of her ability.
朝气蓬勃|这些年轻人朝气蓬勃。|These young people are full of youthful energy.
根深蒂固|这个观念在人们心中根深蒂固。|This idea is deeply rooted in people's minds.
欣欣向荣|这里的经济呈现出欣欣向荣的景象。|The economy here presents a flourishing picture.
污蔑|不能随便污蔑别人。|You must not casually slander other people.
没辙|遇到这种情况，我也没辙了。|In this situation, I am at my wit's end too.
沾光|你得到好机会，我也跟着沾光。|Your good opportunity benefits me too.
涌现|比赛中涌现了很多优秀选手。|Many outstanding competitors emerged in the contest.
涮|吃火锅时，我们涮了一些蔬菜。|We cooked some vegetables briefly in the hotpot.
溶解|糖很容易溶解在水里。|Sugar dissolves easily in water.
滔滔不绝|他讲起旅行的经历就滔滔不绝。|He talks nonstop about his travels.
滞留|因为大雪，旅客滞留在机场。|Because of heavy snow, travelers were stranded at the airport.
潜移默化|父母的行为会潜移默化地影响孩子。|Parents' behavior subtly influences their children.
爱不释手|这本书让她爱不释手。|She loves this book so much that she cannot put it down.
琢磨|他正在琢磨这道题的答案。|He is pondering the answer to this question.
生锈|这把旧锁已经生锈了。|This old lock has rusted.
瘸|受伤后，他的腿有点瘸。|After the injury, he had a slight limp.
相辅相成|学习和练习相辅相成。|Learning and practice complement each other.
瞻仰|游客来到这里瞻仰纪念碑。|Visitors come here to pay their respects at the monument.
称心如意|她终于找到了一份称心如意的工作。|She finally found a job that suited her perfectly.
空前绝后|这次表演的规模堪称空前绝后。|The scale of this performance was unparalleled.
精打细算|为了节省开支，我们要精打细算。|To reduce expenses, we must budget carefully.
精益求精|他对自己的作品总是精益求精。|He always strives to improve his work further.
纵横|这片土地上河流纵横。|Rivers crisscross this land.
络绎不绝|来参观的人络绎不绝。|Visitors arrived in a continuous stream.
继往开来|我们要继往开来，继续努力。|We must build on the past and keep working for the future.
肆无忌惮|不能让他们肆无忌惮地破坏环境。|We must not let them destroy the environment without restraint.
苦尽甘来|经过多年的努力，她终于苦尽甘来。|After years of effort, she finally enjoyed the rewards of her hardship.
蕴藏|这片土地蕴藏着丰富的资源。|This land contains abundant resources.
见多识广|这位老人见多识广。|This elderly person is experienced and knowledgeable.
讨价还价|买东西时，她喜欢讨价还价。|She likes to bargain when shopping.
败坏|这种行为会败坏公司的名声。|This behavior will damage the company's reputation.
贬低|不要通过贬低别人来表现自己。|Do not try to show off by belittling others.
走漏|这个消息不能走漏。|This information must not be leaked.
踌躇|他在门口踌躇了很久。|He hesitated at the entrance for a long time.
蹬|他用力蹬着自行车。|He pedaled the bicycle hard.
迁就|不能事事都迁就孩子。|You cannot give in to a child over everything.
迈|她勇敢地迈出了第一步。|She bravely took the first step.
还原|实验可以把这种物质还原。|The experiment can restore this substance to its original state.
迸发|大家突然迸发出热烈的掌声。|Everyone suddenly burst into enthusiastic applause.
递增|这里的游客数量逐年递增。|The number of visitors here increases year by year.
造反|故事里，人们起来造反了。|In the story, the people rose in rebellion.
遍布|这种植物遍布全国。|This plant is found throughout the country.
锲而不舍|学习需要锲而不舍的精神。|Learning requires perseverance.
难能可贵|他愿意承认错误，这很难能可贵。|His willingness to admit mistakes is commendable.
雪上加霜|生病以后又失去工作，真是雪上加霜。|Losing one's job after getting sick makes a bad situation even worse.
靠拢|请大家向老师靠拢。|Please gather closer to the teacher.
飘扬|国旗在风中飘扬。|The national flag flutters in the wind.
饱经沧桑|这位老人饱经沧桑。|This elderly person has experienced many hardships and changes.
驻扎|这支部队驻扎在边境。|This unit is stationed at the border.
齐心协力|大家齐心协力完成了任务。|Everyone worked together to complete the task.
'''

SPECIAL += """
节|这节课很有意思。|This class is very interesting.
长江|长江是中国重要的河流。|The Yangtze is an important river in China.
名牌|他不在意衣服是不是名牌。|He does not care whether his clothes are a famous brand.
振动|手机突然振动起来。|The phone suddenly began to vibrate.
本科|她正在读本科。|She is studying for an undergraduate degree.
自觉|请大家自觉遵守规定。|Please follow the rules of your own accord.
不像话|你这样对待朋友，太不像话了。|It is outrageous to treat a friend like this.
丢三落四|他出门总是丢三落四。|He always forgets things when going out.
中断|大雨使比赛中断了。|Heavy rain interrupted the match.
丰满|这位画家笔下的人物很丰满。|The characters depicted by this painter are full-bodied.
主导|她在这个项目中起主导作用。|She plays a leading role in this project.
举世瞩目|这场比赛举世瞩目。|This competition attracts worldwide attention.
举动|他友好的举动让大家很感动。|His friendly gesture moved everyone.
乌黑|她有一头乌黑的长发。|She has long jet-black hair.
乡镇|我们走访了附近的乡镇。|We visited the nearby villages and towns.
争先恐后|孩子们争先恐后地回答问题。|The children rushed to answer the question.
争夺|两支队伍正在争夺冠军。|Two teams are competing for the championship.
争气|这孩子很争气，学习一直很认真。|This child makes the family proud by studying diligently.
亏损|这家公司去年出现了亏损。|This company made a loss last year.
交涉|他们正在就这个问题进行交涉。|They are negotiating over this issue.
会晤|两国代表今天举行会晤。|Representatives of the two countries held a meeting today.
依托|这项研究依托当地大学进行。|This research is being conducted with the support of the local university.
俯仰|这个设备可以调节镜头的俯仰角度。|This device can adjust the upward and downward angle of the lens.
倘若|倘若明天下雨，我们就留在家里。|If it rains tomorrow, we will stay home.
假使|假使你有空，请来参加我们的活动。|If you have time, please join our activity.
共鸣|这个故事引起了大家的共鸣。|This story resonated with everyone.
兴致勃勃|她兴致勃勃地介绍自己的计划。|She enthusiastically explained her plan.
兴高采烈|孩子们兴高采烈地走进公园。|The children entered the park in high spirits.
冤枉|请不要冤枉无辜的人。|Please do not falsely accuse innocent people.
凝聚|这次活动凝聚了大家的力量。|This activity brought everyone's strength together.
分泌|这种植物会分泌一种液体。|This plant secretes a liquid.
刑事|他正在研究刑事法律。|He is studying criminal law.
划分|我们把任务划分成三个部分。|We divided the task into three parts.
创业|毕业以后，她决定自己创业。|After graduation, she decided to start her own business.
制约|资金不足制约了公司的发展。|Insufficient funds constrained the company's development.
剥削|不能剥削工人的劳动。|Workers' labor must not be exploited.
剪彩|新商店今天举行剪彩活动。|The new shop held a ribbon-cutting ceremony today.
务实|我们需要采取务实的态度。|We need to take a pragmatic approach.
包庇|不能包庇违法的人。|People who break the law must not be shielded.
化验|医生建议先做一次化验。|The doctor recommended a laboratory test first.
匪徒|警察抓住了逃跑的匪徒。|The police caught the fleeing bandit.
千方百计|她千方百计地帮助朋友。|She tried every possible way to help her friend.
反之|认真准备会有帮助，反之，仓促行动容易失败。|Careful preparation helps; conversely, acting hastily can lead to failure.
发育|孩子的身体正在发育。|The child's body is developing.
受罪|生病的时候，他觉得很受罪。|He felt that being ill was a real ordeal.
合算|买这套书比单独买更合算。|Buying this set of books is more economical than buying them separately.
后顾之忧|有了家人的支持，她没有后顾之忧。|With her family's support, she has no worries holding her back.
启事|门口贴着一张招工启事。|A recruitment notice is posted at the entrance.
吹捧|请客观评价，不要过分吹捧。|Please give an objective assessment without excessive flattery.
周转|这笔钱可以帮助公司周转。|This money can help the company maintain cash flow.
咬牙切齿|想到被骗的经历，他气得咬牙切齿。|Thinking of being cheated made him gnash his teeth in anger.
唾沫|讲话时不要把唾沫喷到别人身上。|Do not spray saliva on others when speaking.
啰唆|请说得简洁一些，不要太啰唆。|Please be concise and not too long-winded.
喜闻乐见|这是一种大家喜闻乐见的表演。|This is a kind of performance that everyone enjoys.
国务院|国务院公布了新的政策。|The State Council announced a new policy.
备份|重要文件一定要有备份。|Important documents must have backup copies.
夏令营|孩子们参加了学校的夏令营。|The children attended the school's summer camp.
多元化|这家公司正在推动业务多元化。|This company is promoting diversification of its business.
天伦之乐|老人和孩子们一起享受天伦之乐。|The elderly people enjoyed family happiness with the children.
奔驰|汽车在宽阔的道路上奔驰。|Cars sped along the wide road.
威风|他穿上制服后显得很威风。|He looked imposing in his uniform.
孕育|这片土地孕育了丰富的文化。|This land has nurtured a rich culture.
实惠|这家饭店的午餐很实惠。|The lunch at this restaurant is good value.
审判|法院正在审判这起案件。|The court is trying this case.
对立|这两种观点并不完全对立。|These two views are not entirely opposed.
对策|我们需要想出合适的对策。|We need to come up with a suitable response.
对联|春节前，家家户户贴上对联。|Before the Spring Festival, households put up couplets.
导航|我用手机导航找到了这家店。|I used my phone's navigation to find this shop.
封锁|警方暂时封锁了这条道路。|The police temporarily blocked off this road.
尖端|这个实验室正在研究尖端技术。|This laboratory is researching cutting-edge technology.
就职|她下个月在新公司就职。|She takes up her position at the new company next month.
屏障|这片森林形成了一道天然屏障。|This forest forms a natural barrier.
岂有此理|你无故欺负别人，真是岂有此理！|It is outrageous to bully others for no reason!
崇敬|大家都很崇敬这位医生。|Everyone deeply respects this doctor.
巡逻|警察正在街上巡逻。|The police are patrolling the street.
师范|她毕业于一所师范大学。|She graduated from a teacher-training university.
应酬|他不喜欢参加太多应酬。|He does not like attending too many social engagements.
庸俗|她不喜欢这种庸俗的玩笑。|She does not like this kind of vulgar joke.
开展|学校正在开展新的活动。|The school is organizing new activities.
归根到底|归根到底，我们还是需要认真学习。|Ultimately, we still need to study seriously.
当务之急|修好这座桥是当务之急。|Repairing this bridge is the most urgent task.
得天独厚|这里有得天独厚的自然条件。|This place enjoys exceptionally favorable natural conditions.
徘徊|他在门外徘徊了很久。|He paced outside the door for a long time.
心眼儿|她心眼儿很好，总是帮助别人。|She is kind-hearted and always helps others.
忌讳|不同的文化有不同的忌讳。|Different cultures have different taboos.
恰到好处|这道菜的味道恰到好处。|The flavor of this dish is just right.
悔恨|他为自己的行为感到悔恨。|He feels remorse for his behavior.
悬崖峭壁|游客沿着悬崖峭壁慢慢前进。|The visitors moved slowly along the steep cliffs.
愣|听到这个消息，他愣了一下。|He was momentarily stunned by the news.
投机|投资不应该只是短期投机。|Investment should not consist merely of short-term speculation.
折腾|别再折腾了，早点休息吧。|Stop fussing and get some rest early.
报到|新生明天到学校报到。|New students report to the school tomorrow.
报答|他希望将来能够报答父母。|He hopes to repay his parents in the future.
拔苗助长|学习需要时间，不能拔苗助长。|Learning takes time; trying to force progress is counterproductive.
排斥|不要排斥不同的意见。|Do not reject differing opinions.
掠夺|战争中，许多资源被掠夺了。|Many resources were plundered during the war.
推理|请说明你的推理过程。|Please explain your reasoning.
摊儿|她在市场上开了一个小摊儿。|She set up a small stall in the market.
摧残|战争摧残了无数家庭。|War devastated countless families.
摩擦|这两个零件之间会产生摩擦。|Friction occurs between these two parts.
支柱|农业是当地经济的重要支柱。|Agriculture is an important pillar of the local economy.
效益|改进方法可以提高经济效益。|Improving the method can increase economic benefits.
敌视|我们不应该敌视不同文化的人。|We should not be hostile toward people from different cultures.
敬礼|士兵向长官敬礼。|The soldier saluted the officer.
敷衍|请认真回答，不要敷衍。|Please answer seriously rather than brushing the question aside.
有条不紊|她做事总是有条不紊。|She always works in an orderly manner.
歌颂|这首歌歌颂了劳动者。|This song praises working people.
歪曲|请不要歪曲我的意思。|Please do not distort my meaning.
歹徒|警察及时制止了歹徒。|The police stopped the criminal in time.
沉思|他坐在窗前沉思。|He sat by the window deep in thought.
泄气|遇到困难时不要泄气。|Do not lose heart when facing difficulties.
波涛汹涌|今天海上波涛汹涌。|The sea is rough with surging waves today.
流通|这种货币在当地广泛流通。|This currency circulates widely in the area.
深情厚谊|我们不会忘记朋友的深情厚谊。|We will not forget our friends' deep affection.
混浊|雨后，河水变得混浊。|After the rain, the river water became muddy.
滋长|不能让这种错误的观念滋长。|We must not let this mistaken idea grow.
激发|这个故事激发了孩子们的兴趣。|This story sparked the children's interest.
牵制|这些问题牵制了我们的精力。|These problems tied up our energy.
率领|她率领团队完成了任务。|She led the team to complete the task.
理直气壮|因为有充分的理由，她说话理直气壮。|With sound reasons on her side, she spoke confidently.
瓦解|这个组织逐渐瓦解了。|This organization gradually fell apart.
直播|电视台正在直播这场比赛。|The television station is broadcasting this match live.
砖瓦|工人正在搬运砖瓦。|Workers are carrying bricks and tiles.
磋商|双方正在就合同进行磋商。|The two sides are discussing the contract.
磨合|新的团队需要时间磨合。|The new team needs time to adjust to one another.
空想|只会空想是不够的，还要行动。|Daydreaming alone is not enough; action is needed too.
管辖|这个地区由当地政府管辖。|This area is administered by the local government.
索赔|产品损坏后，顾客提出了索赔。|After the product was damaged, the customer sought compensation.
纳闷儿|他为什么没来，我一直纳闷儿。|I keep wondering why he did not come.
经商|她的家人一直在这里经商。|Her family has long done business here.
统筹兼顾|做计划时，我们需要统筹兼顾。|When making a plan, we need to consider all aspects together.
腹泻|如果持续腹泻，请及时看医生。|If diarrhea persists, please see a doctor promptly.
苏醒|病人终于苏醒了。|The patient finally regained consciousness.
莫名其妙|这件事让我觉得莫名其妙。|This incident left me puzzled.
萌芽|这些种子已经开始萌芽。|These seeds have begun to sprout.
补偿|公司为损失提供了补偿。|The company provided compensation for the loss.
装卸|工人正在装卸货物。|The workers are loading and unloading goods.
讥笑|不要讥笑别人的错误。|Do not mock other people's mistakes.
记载|这本书记载了当地的历史。|This book records the local history.
诉讼|双方希望通过诉讼解决纠纷。|Both sides hope to resolve the dispute through litigation.
贤惠|她是一位勤劳贤惠的人。|She is a hardworking and caring person.
贪污|政府正在调查贪污案件。|The government is investigating a corruption case.
赞叹|游客们赞叹这里的美景。|The visitors admired the beautiful scenery here.
起义|历史课介绍了这次起义。|The history lesson introduced this uprising.
起哄|请保持安静，不要起哄。|Please stay quiet and do not make a noisy disturbance.
较量|这两支队伍将在明天较量。|These two teams will compete tomorrow.
辐射|这个设备可以测量辐射。|This device can measure radiation.
辩解|他试图为自己的行为辩解。|He tried to justify his behavior.
运算|这台计算机的运算速度很快。|This computer performs calculations very quickly.
进而|我们先了解问题，进而寻找办法。|We first understand the problem and then seek a solution.
连锁|这是一家连锁商店。|This is a chain store.
迟疑|她迟疑了一下才回答。|She hesitated briefly before answering.
适宜|这里的气候适宜种植这种花。|The climate here is suitable for growing this flower.
通俗|请用通俗的语言解释这个问题。|Please explain this issue in plain language.
锦绣前程|大家祝愿她有锦绣前程。|Everyone wishes her a bright future.
问世|这本新书终于问世了。|This new book has finally been published.
附属|这是大学的附属医院。|This is the university's affiliated hospital.
陷害|不能为了利益陷害别人。|You must not frame others for personal gain.
颠簸|汽车在山路上颠簸。|The car jolted along the mountain road.
风土人情|旅行时，她喜欢了解当地的风土人情。|When traveling, she likes learning about local customs and ways of life.
飙升|最近这种商品的价格飙升。|The price of this product has soared recently.
飞跃|这项研究取得了新的飞跃。|This research made a new leap forward.
饱和|市场上的需求已经饱和。|Demand in the market is already saturated.
验收|工程完成后，需要进行验收。|After the project is completed, it needs to be inspected and accepted.
高明|这个办法确实很高明。|This solution is indeed clever.
高涨|大家的学习热情不断高涨。|Everyone's enthusiasm for learning keeps growing.
高考|他正在认真准备高考。|He is diligently preparing for the college entrance examination.
麻痹|不能因为暂时安全就麻痹大意。|We must not become complacent just because we are safe for now.
近视|她有点近视，看不清远处的字。|She is somewhat short-sighted and cannot read words in the distance clearly.
丰满|这幅画中的人物形象很丰满。|The characters in this painting are fully developed.
生疏|很久没练习，这些动作有点生疏了。|After a long time without practice, these movements feel unfamiliar.
简陋|这间房子的设备很简陋。|The equipment in this room is basic.
完备|这套设备的功能很完备。|The functions of this equipment are comprehensive.
优越|这里的自然条件很优越。|The natural conditions here are favorable.
雄厚|这家公司的资金很雄厚。|This company has substantial financial resources.
柔和|房间里的灯光很柔和。|The lighting in the room is gentle.
短促|我们听到了一声短促的叫声。|We heard a brief cry.
猛烈|风刮得很猛烈。|The wind is blowing fiercely.
浓厚|他对历史有浓厚的兴趣。|He has a keen interest in history.
豪迈|这首诗表达了豪迈的感情。|This poem expresses bold and generous feelings.
挺拔|门口那棵树长得很挺拔。|The tree at the entrance stands tall and straight.
崇高|她有崇高的理想。|She has lofty ideals.
庄重|这次仪式非常庄重。|This ceremony is very solemn.
真挚|她表达了真挚的感谢。|She expressed sincere thanks.
狠心|他不忍心做出这么狠心的决定。|He could not bear to make such a cruel decision.
兴隆|这家商店的生意很兴隆。|Business at this shop is thriving.
动荡|那个时期的社会很动荡。|Society was very unstable in that period.
畅通|今天的道路很畅通。|The roads are clear today.
猖狂|这些人的行为越来越猖狂。|These people's behavior is becoming increasingly brazen.
砖瓦|工人正在搬运砖瓦。|The workers are carrying bricks and tiles.
"""

ADJECTIVES = [
('马虎 任性 急躁 虚荣 自满 近视 麻木 恼火 娇气', '他有时候很{word}。', 'He is sometimes {meaning}.'),
('亲热 欢乐 舒畅 快活 狼狈 感慨 诧异 惋惜 拘束 别扭', '她今天显得很{word}。', 'She seems {meaning} today.'),
('虚心 诚恳 沉着 勤恳 廉洁 踏实 高尚 文雅 斯文 慈祥 深沉 体面 神气 生疏', '这位老师给人的感觉很{word}。', 'This teacher gives an impression of being {meaning}.'),
('严密 周密 完备 扎实 坚实 薄弱 优越 雄厚', '这个计划的基础很{word}。', 'The foundation of this plan is {meaning}.'),
('简陋 陈旧 美观 宏伟 别致 对称', '这座建筑的设计很{word}。', 'The design of this building is {meaning}.'),
('柔和 短促 猛烈 浓厚', '她描述了一个{word}的声音。', 'She described a {meaning} sound.'),
('豪迈 挺拔 崇高 庄重 真挚 狠心', '这段话表现出他{word}的一面。', 'These words show his {meaning} side.'),
('荒凉 平坦 曲折', '这一带的地形很{word}。', 'The terrain in this area is {meaning}.'),
('兴隆 动荡 畅通 猖狂', '报纸介绍了当地{word}的情况。', 'The newspaper described the local situation as {meaning}.'),
('丑恶', '我们不能容忍这种{word}的行为。', 'We cannot tolerate such ugly behavior.'),
]

ENGLISH = {
 '口腔':'mouth', '年度':'the year', '智商':'intelligence', '条款':'clause',
 '栏目':'column', '案例':'cases', '股份':'shares', '草案':'draft', '结晶':'crystal',
 '专题':'a particular topic', '股东':'shareholder', '公证':'notarization',
 '共计':'include a total of', '嘉宾':'honored guest', '华裔':'people of Chinese descent', '华侨':'overseas Chinese',
 '伯母':'our aunt', '公婆':'her parents-in-law', '嫂子':'my sister-in-law', '岳父':'my father-in-law',
 '桔子':'tangerines', '佳肴':'delicacies', '糖葫芦':'sugar-coated fruit skewers', '馅儿':'filling',
 '传记':'biographies', '连续剧':'serial dramas', '武侠':'martial-arts stories',
 '池子':'pond', '亭子':'pavilion', '园林':'garden', '港湾':'harbor', '盆地':'basin',
 '公婆':'her parents-in-law', '宏观':'a macro-level perspective', '微观':'a microscopic perspective',
 '俩':'the two of us', '化肥':'fertilizer', '畜牧':'animal husbandry', '经纬':'warp and weft',
 '历代':'successive dynasties', '诞辰':'the anniversary of a birth', '正负':'positive and negative values',
 '利害':'the interests involved', '生机':'vitality', '渣':'residue', '屑':'crumbs',
 '预习':'prepare', '积累':'accumulate', '转告':'pass on', '培育':'raise', '运用':'use', '参照':'refer to', '借鉴':'learn from',
 '维护':'protect', '缩小':'narrow', '拟定':'draft', '制订':'draw up', '部署':'set out',
 '列举':'list', '倡导':'advocate', '兑现':'fulfill', '扩充':'expand', '权衡':'weigh',
 '杜绝':'put an end to', '鉴别':'identify', '辨认':'recognize', '采购':'purchase',
 '饲养':'raise', '安置':'find accommodation for', '慰问':'offer comfort to', '挽救':'save',
 '批判':'criticize', '贯彻':'implement', '落实':'put into practice', '注重':'focus on',
 '钻研':'study in depth', '挖掘':'explore', '考核':'assess', '征收':'levy', '缴纳':'pay',
 '批发':'sell wholesale', '浸泡':'soak', '灌溉':'irrigate', '防守':'defend', '阻拦':'stop',
 '阻挠':'obstruct', '号召':'call on', '鼓动':'encourage', '团圆':'reunite', '联欢':'celebrate together',
 '衔接':'connect', '调解':'mediate', '治理':'address', '表彰':'honor', '请示':'ask for',
 '表态':'make our position clear', '塑造':'build', '展现':'show', '施展':'make full use of',
 '发扬':'develop', '主办':'host', '承办':'organize', '汇报':'report on', '筛选':'select',
 '盖章':'affix a seal', '托运':'check in', '登录':'log in to', '开采':'extract',
 '致辞':'give a speech', '构思':'plan', '起草':'draft', '调动':'mobilize',
 '勉励':'encourage', '督促':'urge', '提拔':'promote', '结算':'settle', '赠送':'give',
 '陈列':'display', '领悟':'grasp', '开阔':'broaden', '谅解':'understand', '宣扬':'promote',
 '调剂':'vary', '防治':'prevent and treat', '反射':'reflect', '分解':'break down',
 '合成':'synthesize', '配合':'cooperate with', '铸造':'cast', '转让':'transfer',
 '揭发':'expose', '谢绝':'politely decline', '拥护':'support', '取缔':'ban', '占有':'possess',
 '查获':'seize', '整顿':'restore', '表决':'vote on', '颁布':'issue', '分红':'distribute dividends',
 '勘探':'explore', '监督':'oversee', '款待':'entertain', '谋求':'seek', '攻克':'solve',
 '调和':'reconcile', '操练':'practice', '熏陶':'nurture', '照应':'refer back to', '防疫':'prevent epidemics',
 '马虎':'careless', '任性':'willful', '急躁':'impatient', '虚荣':'vain', '自满':'complacent',
 '近视':'short-sighted', '麻木':'numb', '恼火':'annoyed', '娇气':'overly delicate',
 '親热':'warm', '亲热':'warm and affectionate', '欢乐':'happy', '舒畅':'at ease', '快活':'happy',
 '狼狈':'flustered', '感慨':'deeply moved', '诧异':'surprised', '惋惜':'regretful',
 '拘束':'self-conscious', '别扭':'awkward', '虚心':'modest', '诚恳':'sincere', '沉着':'calm',
 '勤恳':'diligent', '廉洁':'incorruptible', '踏实':'steady and practical', '高尚':'noble',
 '文雅':'elegant', '斯文':'refined', '慈祥':'kindly', '深沉':'thoughtful', '体面':'dignified',
 '神气':'confident', '生疏':'unfamiliar', '严密':'rigorous', '周密':'carefully planned',
 '完备':'complete', '扎实':'solid', '坚实':'firm', '薄弱':'weak', '优越':'advantageous', '雄厚':'strong',
}

# Reviewed replacements for frames that need a specific context or translation.
SPECIAL += """
华裔|她是一位华裔作家。|She is a writer of Chinese descent.
华侨|许多华侨会回国看望家人。|Many overseas Chinese return to China to visit their families.
发票|请把发票放在桌上。|Please put the receipt on the table.
性质|我们需要了解这种材料的性质。|We need to understand the properties of this material.
纪律|学生应该遵守学校的纪律。|Students should follow the school's rules.
连续剧|我最近很喜欢看这部连续剧。|I have really enjoyed watching this drama series lately.
传记|我最近很喜欢读人物传记。|I have really enjoyed reading biographies lately.
武侠|他喜欢读武侠小说。|He likes reading martial-arts novels.
专科|这所医院有很多专科。|This hospital has many specialist departments.
专长|写作是她的专长。|Writing is her specialty.
专题|我们举办了一场环保专题讲座。|We held a lecture on the topic of environmental protection.
世界观|不同的经历会影响一个人的世界观。|Different experiences can influence a person's worldview.
严密|我们需要制定严密的计划。|We need to draw up a rigorous plan.
周密|她对这次旅行做了周密的安排。|She made thorough arrangements for this trip.
乘务员|乘务员提醒大家系好安全带。|The attendant reminded everyone to fasten their seat belts.
亚军|她在这次比赛中获得了亚军。|She was the runner-up in this competition.
季军|我们队获得了季军。|Our team took third place.
原告|原告向法院提交了证据。|The plaintiff submitted evidence to the court.
兑现|我们需要兑现自己的承诺。|We need to fulfill our promises.
公婆|她今天去看望公婆。|She is visiting her parents-in-law today.
共计|这次活动共计二十人参加。|A total of twenty people took part in this activity.
全局|做决定时，我们要考虑全局。|When making decisions, we must consider the overall situation.
公务|他今天有公务要处理。|He has official business to deal with today.
内幕|记者正在调查这件事的内幕。|The reporter is investigating the inside story of this matter.
内涵|老师解释了这首诗的内涵。|The teacher explained the deeper meaning of this poem.
功劳|这次成功也有你的功劳。|You also deserve credit for this success.
动态|她经常关注行业的最新动态。|She often follows the latest developments in the industry.
劲头|孩子们学习的劲头很足。|The children have plenty of enthusiasm for learning.
压岁钱|孩子们收到了压岁钱，非常开心。|The children were very happy to receive New Year gift money.
原理|老师解释了这台机器的工作原理。|The teacher explained how this machine works.
变故|突如其来的变故改变了我们的计划。|An unexpected event changed our plans.
名次|他在比赛中取得了很好的名次。|He achieved a very good placing in the competition.
名额|这次活动只有二十个名额。|There are only twenty places available for this activity.
周折|经过很多周折，我们终于找到了他。|After many complications, we finally found him.
团圆|春节是家人团圆的日子。|The Spring Festival is a time for families to reunite.
宏观|我们需要从宏观角度分析这个问题。|We need to analyze this issue from a broad perspective.
微观|我们还需要从微观角度分析这个问题。|We also need to analyze this issue at a detailed level.
对称|这座建筑的设计很对称。|The design of this building is symmetrical.
屑|请把桌上的面包屑清理干净。|Please clear the breadcrumbs off the table.
渣|喝完茶后，请清理杯里的茶渣。|After drinking the tea, please clear the tea residue from the cup.
年度|公司公布了年度报告。|The company published its annual report.
序言|请仔细阅读这本书的序言。|Please read this book's preface carefully.
心得|她和我们分享了学习的心得。|She shared what she had learned from studying with us.
心血|这本书花费了她很多心血。|She put a great deal of effort into this book.
悬念|这个故事的结尾留下了悬念。|The ending of this story leaves a sense of suspense.
惯例|按照惯例，我们每周开一次会。|As usual, we hold a meeting once a week.
意向|双方都有合作的意向。|Both sides intend to cooperate.
成效|这种方法取得了很好的成效。|This method produced very good results.
批发|这家公司批发各种水果。|This company sells various fruits wholesale.
智商|智商不能代表一个人的全部能力。|IQ does not represent all of a person's abilities.
曲折|山里的道路非常曲折。|The roads in the mountains are very winding.
机遇|这次旅行给我们带来了新的机遇。|This trip brought us new opportunities.
权益|我们应该保护消费者的权益。|We should protect consumers' rights.
来历|你知道这个名字的来历吗？|Do you know the origin of this name?
标本|实验室保存了许多植物标本。|The laboratory keeps many plant specimens.
格局|这次改革改变了市场的格局。|This reform changed the structure of the market.
案例|老师用一个案例解释了这个问题。|The teacher used a case study to explain this issue.
正月|正月的时候，我们会和家人团聚。|During the first month of the lunar calendar, we get together with our family.
正气|这个故事表现了主人公的正气。|This story shows the protagonist's moral integrity.
气功|她每周都练习气功。|She practices qigong every week.
气势|这座大山气势雄伟。|This great mountain looks majestic.
气魄|这次大胆的决定表现了他的气魄。|This bold decision showed his courage.
泡沫|洗衣服时，水里有很多泡沫。|There is plenty of foam in the water when washing clothes.
泰斗|他是文学界的泰斗。|He is a leading figure in the literary world.
派别|这些艺术家属于不同的派别。|These artists belong to different schools of thought.
焦点|这件事成为了大家讨论的焦点。|This matter became the focus of everyone's discussion.
现状|我们需要先了解公司的现状。|We first need to understand the company's current situation.
百分点|今年的增长率提高了两个百分点。|This year's growth rate rose by two percentage points.
眼色|她向我使了个眼色。|She gave me a meaningful look.
神态|他回答问题时的神态很自然。|His expression was relaxed as he answered the question.
稻谷|农民正在收割稻谷。|The farmers are harvesting rice.
稿件|请把稿件放在桌上。|Please put the manuscript on the table.
章程|请仔细阅读协会的章程。|Please read the association's rules carefully.
籍贯|请确认表上的籍贯是否正确。|Please check that your ancestral place of origin is correct on the form.
红包|孩子们收到了红包，非常开心。|The children were very happy to receive red envelopes containing money.
纪要|请仔细阅读这份会议纪要。|Please read these meeting minutes carefully.
缺口|这座桥的墙上有一个缺口。|There is a gap in the wall on this bridge.
羽绒服|天气很冷，她穿上了羽绒服。|It was very cold, so she put on a down jacket.
联欢|学校举行了一次联欢活动。|The school held a celebration for everyone.
胜负|比赛还没有结束，胜负仍然难以确定。|The match is not over yet, and the outcome is still uncertain.
船舶|博物馆里有船舶的模型。|There is a model of a ship in the museum.
荧屏|她第一次出现在荧屏上。|She appeared on television for the first time.
行列|她加入了志愿者的行列。|She joined the ranks of the volunteers.
见闻|她向我们介绍了旅行中的见闻。|She told us about what she saw and heard on her travels.
觉悟|这件事提高了他的环保觉悟。|This incident increased his environmental awareness.
诞辰|今天是这位作家的诞辰纪念日。|Today is the anniversary of this writer's birth.
贬义|这个词带有贬义。|This word has a negative connotation.
重阳节|重阳节的时候，我们会和家人团聚。|During the Double Ninth Festival, we get together with our family.
钻研|她正在钻研这个问题。|She is studying this problem in depth.
阻挠|有人试图阻挠计划的实施。|Someone tried to obstruct the implementation of the plan.
面貌|这个村子的面貌发生了很大变化。|The appearance of this village has changed a great deal.
魄力|她处理问题很有魄力。|She handles problems with courage and determination.
麻木|坐了很久以后，他的腿有些麻木。|After sitting for a long time, his legs felt somewhat numb.
饱和|这种商品的市场已经饱和。|The market for this product is already saturated.
丰满|小说中的人物形象很丰满。|The characters in this novel are well developed.
常务|常务委员会每月开一次会。|The standing committee meets once a month.
欢乐|孩子们的笑声充满了欢乐。|The children's laughter was full of joy.
惋惜|大家对这个结果感到惋惜。|Everyone felt regret over this outcome.
感慨|听到这个故事，她感慨万分。|She was deeply moved on hearing this story.
借鉴|我们可以借鉴别人的经验。|We can learn from other people's experience.
熏陶|她从小受到艺术的熏陶。|She has been influenced by art since childhood.
分红|公司今年给股东分红了。|The company distributed dividends to shareholders this year.
方针|公司制定了新的经营方针。|The company drew up a new business policy.
招投标|这项工程需要进行招投标。|This project needs to go through a tendering process.
条款|请仔细阅读合同中的条款。|Please read the clauses in the contract carefully.
边疆|他希望去边疆工作。|He hopes to work in a border region.
预习|请在上课前预习课文。|Please prepare the lesson text before class.
恨不得|我恨不得马上见到家人。|I wish I could see my family right away.
恩怨|他们决定忘记过去的恩怨。|They decided to put their past grievances behind them.
弊病|这种制度有不少弊病。|This system has quite a few flaws.
弊端|我们需要解决旧制度的弊端。|We need to address the drawbacks of the old system.
差距|两队之间的差距很小。|The gap between the two teams is very small.
纠纷|他们希望通过谈判解决纠纷。|They hope to resolve the dispute through negotiation.
隐患|检查发现了一处安全隐患。|The inspection found a safety hazard.
隔阂|坦诚的交流消除了他们之间的隔阂。|Frank communication removed the barriers between them.
颈椎|医生仔细检查了他的颈椎。|The doctor carefully examined his cervical spine.
颗粒|这种材料的颗粒很小。|The particles of this material are very small.
盆地|这片盆地的土地非常肥沃。|The soil in this basin is very fertile.
立交桥|汽车正在通过立交桥。|Cars are passing over the interchange.
公安局|她去公安局办理手续。|She went to the public security bureau to complete the paperwork.
附件|请仔细阅读邮件中的附件。|Please read the attachment to the email carefully.
标记|地图上的标记表示医院的位置。|The marker on the map indicates the hospital's location.
规格|购买之前，请确认产品的规格。|Please check the product specifications before buying.
阵容|这次比赛的阵容很强。|The lineup for this competition is very strong.
嘉宾|今天的嘉宾是一位著名的作家。|Today's guest is a famous writer.
神气|他穿着新衣服，看起来很神气。|He looks very proud in his new clothes.
公婆|她今天去看望公婆。|She is visiting her parents-in-law today.
体面|她找到了一个体面的工作。|She found a respectable job.
廉洁|大家都尊敬这位廉洁的官员。|Everyone respects this honest official.
勤恳|他工作勤恳，从不抱怨。|He works diligently and never complains.
虚心|我们应该虚心听取别人的意见。|We should humbly listen to other people's opinions.
诚恳|她的态度很诚恳。|Her attitude is very sincere.
扎实|他的汉语基础很扎实。|He has a solid foundation in Chinese.
坚实|长期的努力为成功打下了坚实的基础。|Long-term effort laid a firm foundation for success.
薄弱|词汇是他学习中的薄弱环节。|Vocabulary is the weak point in his studies.
"""

# Explicit supporting readings override contextual particles and polyphonic words.
SUPPORT = {
 '作家':'zuò jiā', '环保':'huán bǎo', '今年':'jīn nián',
 '关注':'guān zhù', '行业':'háng yè', '最新':'zuì xīn', '足':'zú',
 '突如其来':'tū rú qí lái', '分享':'fēn xiǎng', '花费':'huā fèi',
 '结尾':'jié wěi', '留下':'liú xià', '主人公':'zhǔ rén gōng',
 '大胆':'dà dǎn', '杯':'bēi', '增长率':'zēng zhǎng lǜ',
 '两个':'liǎng ge', '表':'biǎo', '加入':'jiā rù', '志愿者':'zhì yuàn zhě',
 '购买':'gòu mǎi', '纪念日':'jì niàn rì', '词':'cí', '带有':'dài yǒu',
 '强':'qiáng', '邮件':'yóu jiàn', '坦诚':'tǎn chéng', '消除':'xiāo chú',
 '种了':'zhòng le', '的':'de', '地':'de', '得':'de', '了':'le', '着':'zhe', '过':'guo',
 '一':'yī', '不':'bù', '还有':'hái yǒu', '还要':'hái yào', '还会':'hái huì',
 '种植':'zhòng zhí', '种':'zhǒng', '为':'wèi', '作为':'zuò wéi', '为了':'wèi le',
 '长大':'zhǎng dà', '银行':'yín háng', '行列':'háng liè', '同行':'tóng háng',
 '很':'hěn', '都':'dōu', '来':'lái', '把':'bǎ', '去':'qù', '在':'zài',
 '这位':'zhè wèi', '这份':'zhè fèn', '这处':'zhè chù', '这张':'zhè zhāng',
 '这条':'zhè tiáo', '这块':'zhè kuài', '这片':'zhè piàn', '这支':'zhè zhī',
 '这段':'zhè duàn', '这间':'zhè jiān', '这套':'zhè tào', '这点':'zhè diǎn',
 '这本':'zhè běn', '这座':'zhè zuò', '这项':'zhè xiàng', '这道':'zhè dào',
 '这一':'zhè yī', '这双':'zhè shuāng', '这件':'zhè jiàn', '这艘':'zhè sōu',
 '这次':'zhè cì', '这把':'zhè bǎ', '这扇':'zhè shàn', '这几':'zhè jǐ',
 '她':'tā', '他':'tā', '我们':'wǒ men', '他们':'tā men', '人们':'rén men',
 '孩子们':'hái zi men', '同学们':'tóng xué men', '这些':'zhè xiē',
 '看望':'kàn wàng', '团聚':'tuán jù', '含有':'hán yǒu', '门口':'mén kǒu',
 '院长':'yuàn zhǎng', '表面':'biǎo miàn', '从来':'cóng lái', '以来':'yǐ lái',
 '不周':'bù zhōu', '一面':'yī miàn', '股东':'gǔ dōng', '之一':'zhī yī',
 '处分':'chǔ fèn', '供应':'gōng yìng', '供求':'gōng qiú', '会':'huì',
 '中国':'Zhōng guó', '汉语':'Hàn yǔ', '春节':'Chūn jié',
}

SUPPORT.update(dict(item.split(':', 1) for item in """
中:zhōng 么:me 事:shì 于:yú 产:chǎn 们:men 例:lì 停:tíng 入:rù 全:quán 农:nóng 前:qián 力:lì 动:dòng 助:zhù 午:wǔ 单:dān 受:shòu 变:biàn 同:tóng 名:míng 后:hòu 员:yuán 周:zhōu 品:pǐn 喷:pēn 国:guó 堂:táng 堪:kān 声:shēng 处:chù 天:tiān 头:tóu 子:zi 学:xué 客:kè 室:shì 害:hài 寒:hán 封:fēng 将:jiāng 山:shān 工:gōng 帮:bāng 常:cháng 并:bìng 广:guǎng 店:diàn 形:xíng 心:xīn 忍:rěn 性:xìng 意:yì 感:gǎn 愿:yuàn 成:chéng 户:hù 房:fáng 扇:shàn 打:dǎ 抓:zhuā 招:zhāo 损:sǔn 掌:zhǎng 故:gù 文:wén 旅:lǚ 旗:qí 既:jì 早:zǎo 时:shí 景:jǐng 替:tì 期:qī 木:mù 机:jī 李:li 村:cūn 板:bǎn 样:yàng 桌:zhuō 款:kuǎn 歌:gē 步:bù 母:mǔ 气:qì 汽:qì 沙:shā 沿:yán 法:fǎ 泥:ní 洁:jié 流:liú 海:hǎi 清:qīng 温:wēn 游:yóu 灾:zāi 然:rán 父:fù 物:wù 生:shēng 田:tián 电:diàn 界:jiè 病:bìng 相:xiāng 眼:yǎn 矿:kuàng 研:yán 碑:bēi 称:chēng 程:chéng 究:jiū 空:kōng 窗:chuāng 笔:bǐ 简:jiǎn 线:xiàn 织:zhī 罪:zuì 美:měi 者:zhě 街:jiē 见:jiàn 观:guān 警:jǐng 访:fǎng 话:huà 说:shuō 豆:dòu 象:xiàng 账:zhàng 货:huò 贴:tiē 起:qǐ 跑:pǎo 身:shēn 车:chē 载:zǎi 辜:gū 运:yùn 违:wéi 适:shì 选:xuǎn 道:dào 部:bù 间:jiān 阔:kuò 队:duì 降:jiàng 雨:yǔ 风:fēng 餐:cān 饭:fàn 首:shǒu
""".split()))


def examples(vocabulary, missing_ids):
    by_word = {w['simplified']: w for w in vocabulary}
    assigned = {}
    for groups in (GROUPS, ADJECTIVES):
        for words, chinese, english in groups:
            for word in words.split():
                if word in by_word:
                    meaning = ENGLISH.get(word, by_word[word]['studyMeaning'])
                    meaning = re.sub(r'\([^)]*\)', '', meaning).strip()
                    meaning = re.sub(r'^(a|an|the)\s+', '', meaning)
                    meaning = meaning.split(';')[0].split('；')[0].strip()
                    assigned[word] = (chinese.format(word=word), english.format(meaning=meaning))
    for words, obj, obj_en in VERBS:
        for word in words.split():
            if word in by_word:
                meaning = ENGLISH.get(word, by_word[word]['studyMeaning'].removeprefix('to '))
                assigned[word] = (f'我们需要{word}{obj}。', f'We need to {meaning} {obj_en}.'.replace(' .', '.'))
    for row in SPECIAL.strip().splitlines():
        if not row.strip():
            continue
        word, chinese, english = row.split('|')
        assigned[word] = (chinese, english)
    # All original examples are explicit choices; regeneration reports uncovered
    # words so an editor can add a natural, sense-specific example.
    missing = [by_word_id for by_word_id in missing_ids
               if next(w for w in vocabulary if w['id'] == by_word_id)['simplified'] not in assigned]
    if missing:
        return assigned, missing
    return assigned, []


def pinyin_for(chinese, word, vocabulary):
    readings = {w['simplified']: w['pinyin'] for w in vocabulary}
    readings.update(SUPPORT)
    readings[word['simplified']] = word['pinyin']
    maximum = max(map(len, readings))
    # Do not let a dictionary token span the target's boundary: in 书记载,
    # 书记 is not the intended word. Always retain the target entry's reading.
    target_start = chinese.index(word['simplified'])
    target_end = target_start + len(word['simplified'])
    result = []
    cursor = 0
    while cursor < len(chinese):
        if not re.match(r'[\u3400-\u9fff]', chinese[cursor]):
            result.append(chinese[cursor])
            cursor += 1
            continue
        if cursor == target_start:
            result.append(' ' + word['pinyin'] + ' ')
            cursor = target_end
            continue
        limit = target_start - cursor if cursor < target_start else len(chinese) - cursor
        token = next((chinese[cursor:cursor + length] for length in
                      range(min(maximum, limit), 0, -1)
                      if chinese[cursor:cursor + length] in readings), None)
        if token is None:
            raise ValueError(f'Missing supporting pinyin in {chinese!r} at {chinese[cursor:]!r}')
        result.append(' ' + readings[token] + ' ')
        cursor += len(token)
    text = re.sub(r'\s+', ' ', ''.join(result)).strip()
    text = re.sub(r'\s+([。，、？！：；])', r'\1', text)
    return text[0].upper() + text[1:]


if __name__ == '__main__':
    vocabulary = json.loads(Path('assets/data/hsk_vocabulary.json').read_text())
    curriculum = json.loads(Path('assets/data/vocabulary_lessons.json').read_text())
    original_path = Path('assets/data/lesson_original_examples.json')
    missing_ids = set(json.loads(original_path.read_text())) if original_path.exists() else set()
    missing_ids.update(row['vocabularyId'] for row in curriculum['missingExamples'])
    overrides = json.loads(Path('assets/data/tatoeba/lesson_example_overrides.json').read_text())
    missing_ids.update(entry_id for entry_id, choice in overrides.items() if choice.get('omit'))
    assigned, missing = examples(vocabulary, missing_ids)
    if missing:
        by_id = {w['id']: w for w in vocabulary}
        print('NEED ORIGINAL EXAMPLES:', len(missing))
        for entry_id in sorted(missing):
            w = by_id[entry_id]
            print(w['simplified'] + '=' + w['studyMeaning'])
        raise SystemExit(1)
    output = {}
    for word in vocabulary:
        if word['id'] not in missing_ids:
            continue
        chinese, english = assigned[word['simplified']]
        output[word['id']] = {'chinese': chinese, 'pinyin': pinyin_for(chinese, word, vocabulary),
                              'english': english, 'source': 'Original'}
    original_path.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    print(f'Wrote {len(output)} original examples.')
