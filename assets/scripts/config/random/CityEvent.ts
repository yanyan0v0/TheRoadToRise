// 配置随机事件列表
export default {
  school: [
    {
      id: 1,
      title: "书院辩论赛",
      description: "书院举办了一场激烈的辩论赛，你被选为辩手",
      options: [
        { text: "积极参与辩论", effect: { 智力: 5 } },
        { text: "保守应对", effect: { 智力: 2, 武力: 1 } },
        { text: "放弃参赛", effect: { 名声: -3 } }
      ]
    },
    {
      id: 2,
      title: "古籍修复",
      description: "发现一本破损的古籍，需要修复",
      options: [
        { text: "仔细修复", effect: { 智力: 4, 耐力: 2 } },
        { text: "快速修复", effect: { 智力: 1, 武力: 2 } }
      ]
    },
    {
      id: 3,
      title: "诗词大会",
      description: "书院举办诗词大会，邀请你参加",
      options: [
        { text: "即兴创作", effect: { 智力: 6, 武力: 1 } },
        { text: "背诵经典", effect: { 智力: 3 } }
      ]
    },
    {
      id: 4,
      title: "师长教诲",
      description: "师长单独找你谈话，给予指导",
      options: [
        { text: "虚心接受", effect: { 智力: 5 } },
        { text: "敷衍了事", effect: { 名声: -2 } }
      ]
    },
    {
      id: 5,
      title: "同窗求助",
      description: "同窗在学业上遇到困难，向你求助",
      options: [
        { text: "热心帮助", effect: { 名声: 3, 智力: 1 } },
        { text: "推脱拒绝", effect: { 名声: -3 } }
      ]
    },
    {
      id: 6,
      title: "夜读遇难题",
      description: "深夜读书时遇到难以理解的章节",
      options: [
        { text: "彻夜研究", effect: { 智力: 5, energy: -2 } },
        { text: "明日再解", effect: { 智力: 1 } }
      ]
    },
    {
      id: 7,
      title: "书法练习",
      description: "师长要求你练习书法",
      options: [
        { text: "认真练习", effect: { 耐力: 4, 智力: 2 } },
        { text: "草草了事", effect: { 名声: -2 } }
      ]
    },
    {
      id: 8,
      title: "经义考试",
      description: "书院举行经义考试",
      options: [
        { text: "全力以赴", effect: { 智力: 6, 武力: 2 } },
        { text: "应付考试", effect: { 智力: 2 } }
      ]
    },
    {
      id: 9,
      title: "藏书阁整理",
      description: "被安排整理藏书阁的书籍",
      options: [
        { text: "仔细分类", effect: { 智力: 3, 耐力: 3 } },
        { text: "快速完成", effect: { 智力: 1, 武力: 1 } }
      ]
    },
    {
      id: 10,
      title: "学术交流",
      description: "外地学者来访，进行学术交流",
      options: [
        { text: "积极参与", effect: { 智力: 4, 名声: 2 } },
        { text: "保持沉默", effect: { 智力: 1 } }
      ]
    }
  ],
  restaurant: [
    {
      id: 1,
      title: "美食评选",
      description: "酒楼举办美食评选活动",
      options: [
        { text: "担任评委", effect: { 名声: 3, 生命值: 1 } },
        { text: "品尝美食", effect: { 生命值: 2, 金币: -5 } }
      ]
    },
    {
      id: 2,
      title: "食材采购",
      description: "需要采购新鲜食材",
      options: [
        { text: "精心挑选", effect: { 生命值: 3, 金币: -3 } },
        { text: "普通采购", effect: { 生命值: 1 } }
      ]
    },
    {
      id: 3,
      title: "厨艺比拼",
      description: "与厨师进行厨艺比拼",
      options: [
        { text: "展示厨艺", effect: { 名声: 4, 武力: 1 } },
        { text: "观摩学习", effect: { 智力: 2 } }
      ]
    },
    {
      id: 4,
      title: "贵客到访",
      description: "有贵客到访酒楼",
      options: [
        { text: "热情接待", effect: { 名声: 5, 金币: 3 } },
        { text: "普通服务", effect: { 名声: 1 } }
      ]
    },
    {
      id: 5,
      title: "新菜研发",
      description: "需要研发新菜品",
      options: [
        { text: "创新尝试", effect: { 名声: 4, 金币: -2 } },
        { text: "保守改良", effect: { 名声: 2 } }
      ]
    },
    {
      id: 6,
      title: "食材短缺",
      description: "某种重要食材短缺",
      options: [
        { text: "高价采购", effect: { 生命值: 3, 金币: -8 } },
        { text: "寻找替代", effect: { 生命值: 1, 智力: 2 } }
      ]
    },
    {
      id: 7,
      title: "酒水品鉴",
      description: "新到一批美酒需要品鉴",
      options: [
        { text: "仔细品鉴", effect: { 名声: 3, 生命值: -1 } },
        { text: "浅尝辄止", effect: { 名声: 1 } }
      ]
    },
    {
      id: 8,
      title: "节日宴席",
      description: "准备节日宴席",
      options: [
        { text: "精心准备", effect: { 名声: 6, 武力: 2 } },
        { text: "标准准备", effect: { 名声: 3 } }
      ]
    },
    {
      id: 9,
      title: "顾客投诉",
      description: "有顾客对菜品不满意",
      options: [
        { text: "诚恳道歉", effect: { 名声: 2, 武力: 1 } },
        { text: "据理力争", effect: { 名声: -3 } }
      ]
    },
    {
      id: 10,
      title: "特色菜品",
      description: "推出特色菜品",
      options: [
        { text: "大力推广", effect: { 名声: 4, 金币: 3 } },
        { text: "低调推出", effect: { 名声: 2 } }
      ]
    }
  ],
  inn: [
    {
      id: 1,
      title: "客房整理",
      description: "需要整理客房",
      options: [
        { text: "仔细打扫", effect: { 名声: 3, energy: -1 } },
        { text: "简单整理", effect: { 名声: 1 } }
      ]
    },
    {
      id: 2,
      title: "旅客求助",
      description: "旅客遇到困难向你求助",
      options: [
        { text: "热心帮助", effect: { 名声: 4, 金币: 2 } },
        { text: "婉言拒绝", effect: { 名声: -2 } }
      ]
    },
    {
      id: 3,
      title: "设施维护",
      description: "客栈设施需要维护",
      options: [
        { text: "及时维修", effect: { 名声: 3, 金币: -3 } },
        { text: "暂时搁置", effect: { 名声: -1 } }
      ]
    },
    {
      id: 4,
      title: "深夜投宿",
      description: "深夜有旅客投宿",
      options: [
        { text: "热情接待", effect: { 名声: 4, energy: -2 } },
        { text: "婉拒入住", effect: { 名声: -3 } }
      ]
    },
    {
      id: 5,
      title: "物品遗失",
      description: "旅客遗失贵重物品",
      options: [
        { text: "帮助寻找", effect: { 名声: 5, 武力: 1 } },
        { text: "推卸责任", effect: { 名声: -4 } }
      ]
    },
    {
      id: 6,
      title: "旺季经营",
      description: "旅游旺季客流量大",
      options: [
        { text: "提高服务", effect: { 名声: 4, 金币: 5, 武力: 2 } },
        { text: "维持现状", effect: { 名声: 2, 金币: 2 } }
      ]
    },
    {
      id: 7,
      title: "食材采购",
      description: "需要采购食材供应餐饮",
      options: [
        { text: "优质采购", effect: { 生命值: 3, 金币: -4 } },
        { text: "普通采购", effect: { 生命值: 1 } }
      ]
    },
    {
      id: 8,
      title: "同行竞争",
      description: "附近新开一家客栈",
      options: [
        { text: "提升服务", effect: { 名声: 4, 金币: -3 } },
        { text: "价格竞争", effect: { 名声: 2, 金币: 1 } }
      ]
    },
    {
      id: 9,
      title: "旅客纠纷",
      description: "旅客之间发生纠纷",
      options: [
        { text: "调解处理", effect: { 名声: 3, 武力: 1 } },
        { text: "置之不理", effect: { 名声: -3 } }
      ]
    },
    {
      id: 10,
      title: "节日装饰",
      description: "需要装饰客栈迎接节日",
      options: [
        { text: "精心装饰", effect: { 名声: 3, 金币: -2 } },
        { text: "简单装饰", effect: { 名声: 1 } }
      ]
    }
  ],
  county_hall: [
    {
      id: 1,
      title: "案件审理",
      description: "需要审理一桩民事案件",
      options: [
        { text: "公正审理", effect: { 名声: 5, 智力: 2 } },
        { text: "偏袒一方", effect: { 名声: -4, 金币: 3 } }
      ]
    },
    {
      id: 2,
      title: "税收征收",
      description: "需要征收地方税收",
      options: [
        { text: "合理征收", effect: { 名声: 3, 金币: 4 } },
        { text: "加重征收", effect: { 名声: -3, 金币: 6 } }
      ]
    },
    {
      id: 3,
      title: "民事调解",
      description: "村民之间发生纠纷",
      options: [
        { text: "耐心调解", effect: { 名声: 4, 智力: 2 } },
        { text: "强制处理", effect: { 名声: -2 } }
      ]
    },
    {
      id: 4,
      title: "政策传达",
      description: "需要传达朝廷新政",
      options: [
        { text: "详细解释", effect: { 名声: 3, 智力: 1 } },
        { text: "简单通知", effect: { 名声: 1 } }
      ]
    },
    {
      id: 5,
      title: "灾情应对",
      description: "发生自然灾害需要应对",
      options: [
        { text: "全力救灾", effect: { 名声: 6, 金币: -5, 武力: 2 } },
        { text: "有限应对", effect: { 名声: 2 } }
      ]
    },
    {
      id: 6,
      title: "官员来访",
      description: "上级官员前来视察",
      options: [
        { text: "精心准备", effect: { 名声: 4, 金币: -3 } },
        { text: "常规接待", effect: { 名声: 1 } }
      ]
    },
    {
      id: 7,
      title: "治安维护",
      description: "需要加强治安管理",
      options: [
        { text: "加强巡逻", effect: { 名声: 3, 金币: -2 } },
        { text: "维持现状", effect: { 名声: 1 } }
      ]
    },
    {
      id: 8,
      title: "文书处理",
      description: "积压大量文书需要处理",
      options: [
        { text: "加班处理", effect: { 名声: 3, 武力: 2 } },
        { text: "分批处理", effect: { 名声: 1 } }
      ]
    },
    {
      id: 9,
      title: "民生调查",
      description: "需要进行民生状况调查",
      options: [
        { text: "深入调查", effect: { 名声: 4, 智力: 2 } },
        { text: "表面调查", effect: { 名声: 1 } }
      ]
    },
    {
      id: 10,
      title: "建设规划",
      description: "需要规划地方建设",
      options: [
        { text: "长远规划", effect: { 名声: 4, 智力: 3 } },
        { text: "短期规划", effect: { 名声: 2 } }
      ]
    }
  ],
  clinic: [
    {
      id: 1,
      title: "急诊病人",
      description: "有急诊病人需要救治",
      options: [
        { text: "全力救治", effect: { 名声: 5, 生命值: 3, 武力: 1 } },
        { text: "保守治疗", effect: { 名声: 2, 生命值: 1 } }
      ]
    },
    {
      id: 2,
      title: "药材采购",
      description: "需要采购药材",
      options: [
        { text: "优质药材", effect: { 生命值: 4, 金币: -4 } },
        { text: "普通药材", effect: { 生命值: 2 } }
      ]
    },
    {
      id: 3,
      title: "疑难杂症",
      description: "遇到疑难病症",
      options: [
        { text: "深入研究", effect: { 智力: 4, 生命值: 2, 武力: 1 } },
        { text: "转诊他处", effect: { 名声: -2 } }
      ]
    },
    {
      id: 4,
      title: "义诊活动",
      description: "举办义诊活动",
      options: [
        { text: "积极参与", effect: { 名声: 4, 生命值: 2, 金币: -2 } },
        { text: "有限参与", effect: { 名声: 2 } }
      ]
    },
    {
      id: 5,
      title: "药方改良",
      description: "需要改良传统药方",
      options: [
        { text: "大胆创新", effect: { 智力: 5, 生命值: 3, 武力: 1 } },
        { text: "保守改良", effect: { 智力: 2, 生命值: 1 } }
      ]
    },
    {
      id: 6,
      title: "瘟疫防治",
      description: "需要防治瘟疫",
      options: [
        { text: "全面防治", effect: { 名声: 6, 生命值: 4, 武力: 2 } },
        { text: "局部防治", effect: { 名声: 3, 生命值: 2 } }
      ]
    },
    {
      id: 7,
      title: "医术传承",
      description: "需要传授医术",
      options: [
        { text: "悉心传授", effect: { 名声: 4, 智力: 2 } },
        { text: "简单指导", effect: { 名声: 1 } }
      ]
    },
    {
      id: 8,
      title: "药品研发",
      description: "研发新药品",
      options: [
        { text: "深入研究", effect: { 智力: 5, 生命值: 3, 金币: -3 } },
        { text: "基础研究", effect: { 智力: 2, 生命值: 1 } }
      ]
    },
    {
      id: 9,
      title: "医疗设备",
      description: "需要更新医疗设备",
      options: [
        { text: "先进设备", effect: { 生命值: 4, 金币: -5 } },
        { text: "普通设备", effect: { 生命值: 2 } }
      ]
    },
    {
      id: 10,
      title: "健康讲座",
      description: "举办健康知识讲座",
      options: [
        { text: "精心准备", effect: { 名声: 4, 生命值: 2 } },
        { text: "常规讲座", effect: { 名声: 2 } }
      ]
    }
  ],
  blacksmith: [
    {
      id: 1,
      title: "武器打造",
      description: "需要打造一批武器",
      options: [
        { text: "精工打造", effect: { 名声: 4, 体质: 2, 金币: 3 } },
        { text: "普通打造", effect: { 名声: 2, 体质: 1 } }
      ]
    },
    {
      id: 2,
      title: "材料短缺",
      description: "重要锻造材料短缺",
      options: [
        { text: "高价采购", effect: { 体质: 3, 金币: -4 } },
        { text: "寻找替代", effect: { 体质: 1, 智力: 2 } }
      ]
    },
    {
      id: 3,
      title: "特殊订单",
      description: "接到特殊武器订单",
      options: [
        { text: "接受挑战", effect: { 名声: 5, 体质: 3, 武力: 1 } },
        { text: "婉拒订单", effect: { 名声: -2 } }
      ]
    },
    {
      id: 4,
      title: "技艺传承",
      description: "需要传授锻造技艺",
      options: [
        { text: "悉心传授", effect: { 名声: 3, 智力: 2 } },
        { text: "简单指导", effect: { 名声: 1 } }
      ]
    },
    {
      id: 5,
      title: "设备维护",
      description: "锻造设备需要维护",
      options: [
        { text: "全面维护", effect: { 体质: 2, 金币: -2 } },
        { text: "基本维护", effect: { 体质: 1 } }
      ]
    },
    {
      id: 6,
      title: "创新设计",
      description: "需要设计新式武器",
      options: [
        { text: "大胆创新", effect: { 智力: 4, 体质: 3, 武力: 1 } },
        { text: "传统设计", effect: { 智力: 2, 体质: 2 } }
      ]
    },
    {
      id: 7,
      title: "批量生产",
      description: "需要批量生产武器",
      options: [
        { text: "保证质量", effect: { 名声: 4, 体质: 2, 金币: 4 } },
        { text: "提高产量", effect: { 名声: 2, 体质: 1, 金币: 6 } }
      ]
    },
    {
      id: 8,
      title: "武器修复",
      description: "需要修复古兵器",
      options: [
        { text: "精心修复", effect: { 名声: 4, 智力: 2 } },
        { text: "基本修复", effect: { 名声: 2 } }
      ]
    },
    {
      id: 9,
      title: "材料研究",
      description: "研究新材料应用",
      options: [
        { text: "深入研究", effect: { 智力: 5, 体质: 3, 金币: -3 } },
        { text: "基础研究", effect: { 智力: 2, 体质: 1 } }
      ]
    },
    {
      id: 10,
      title: "锻造比赛",
      description: "参加锻造技艺比赛",
      options: [
        { text: "全力以赴", effect: { 名声: 5, 体质: 3, 武力: 1 } },
        { text: "重在参与", effect: { 名声: 2 } }
      ]
    }
  ],
  market: [
    {
      id: 1,
      title: "商品采购",
      description: "需要采购商品",
      options: [
        { text: "精挑细选", effect: { 金币: 4, 智力: 1 } },
        { text: "批量采购", effect: { 金币: 2 } }
      ]
    },
    {
      id: 2,
      title: "价格谈判",
      description: "与供应商进行价格谈判",
      options: [
        { text: "强硬谈判", effect: { 金币: 5, 名声: -1 } },
        { text: "温和谈判", effect: { 金币: 3, 名声: 1 } }
      ]
    },
    {
      id: 3,
      title: "新品推广",
      description: "推广新商品",
      options: [
        { text: "大力推广", effect: { 名声: 4, 金币: 3, 武力: 1 } },
        { text: "逐步推广", effect: { 名声: 2, 金币: 1 } }
      ]
    },
    {
      id: 4,
      title: "竞争对手",
      description: "出现新的竞争对手",
      options: [
        { text: "提升服务", effect: { 名声: 4, 金币: 2 } },
        { text: "价格竞争", effect: { 名声: 2, 金币: 4 } }
      ]
    },
    {
      id: 5,
      title: "库存管理",
      description: "需要管理库存",
      options: [
        { text: "精细管理", effect: { 金币: 3, 智力: 2 } },
        { text: "粗放管理", effect: { 金币: 1 } }
      ]
    },
    {
      id: 6,
      title: "促销活动",
      description: "举办促销活动",
      options: [
        { text: "大型促销", effect: { 金币: 6, 名声: 2, 武力: 1 } },
        { text: "小型促销", effect: { 金币: 3, 名声: 1 } }
      ]
    },
    {
      id: 7,
      title: "客户投诉",
      description: "处理客户投诉",
      options: [
        { text: "妥善处理", effect: { 名声: 3, 武力: 1 } },
        { text: "敷衍了事", effect: { 名声: -3 } }
      ]
    },
    {
      id: 8,
      title: "市场调研",
      description: "进行市场调研",
      options: [
        { text: "深入调研", effect: { 智力: 4, 金币: 2 } },
        { text: "表面调研", effect: { 智力: 1 } }
      ]
    },
    {
      id: 9,
      title: "供应链优化",
      description: "优化供应链",
      options: [
        { text: "全面优化", effect: { 金币: 4, 智力: 2, 武力: 1 } },
        { text: "局部优化", effect: { 金币: 2 } }
      ]
    },
    {
      id: 10,
      title: "节日销售",
      description: "节日期间销售",
      options: [
        { text: "全力销售", effect: { 金币: 5, 名声: 2, 武力: 1 } },
        { text: "正常销售", effect: { 金币: 3 } }
      ]
    }
  ]
}