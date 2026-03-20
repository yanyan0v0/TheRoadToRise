export interface RandomEvent {
  id: string;
  title: string;
  description: string;
  gameContent: string;
  options: {
    confirm: {
      text: string;
      effect?: Record<string, number>;
    };
    cancel: {
      text: string;
      effect?: Record<string, number>;
    };
  };
}

// 配置随机事件列表
export default {
  school: [
    {
      id: "01",
      title: "书院辩论赛",
      description: "参加书院举办的探讨“理学”与“心学”优劣的辩论赛",
      gameContent: "打字拼手速，限定时间内打出对应的文字，不能有错别字",
      options: {
        confirm: { text: "接受" },
        cancel: { text: "拒绝", effect: { 名声: -1 } },
      },
    },
    {
      id: "02",
      title: "古籍修复",
      description: "发现一本破损的古籍，需要修复",
      gameContent: "拼图游戏，将散乱的古籍拼接起来，恢复完整",
      options: {
        confirm: { text: "接受" },
        cancel: { text: "拒绝", effect: { 名声: -1 } },
      },
    },
    {
      id: "03",
      title: "诗词大会",
      description: "书院举办诗词大会，邀请你参加",
      gameContent: "诗词填空，根据提示填写合适的诗句",
      options: {
        confirm: { text: "接受" },
        cancel: { text: "拒绝", effect: { 名声: -1 } },
      },
    },
    {
      id: "04",
      title: "聆听讲座",
      description: "德高望重的院长正在举办儒家修身与治国之道的讲座",
      gameContent: "播放一段带口音的音频，需要听懂并回答问题",
      options: {
        confirm: { text: "接受" },
        cancel: { text: "拒绝", effect: { 名声: -1 } },
      },
    },
    {
      id: "05",
      title: "同窗求助",
      description: "同窗在算术上遇到困难，向你求助",
      gameContent: "一道数学题，写出答案",
      options: {
        confirm: { text: "接受" },
        cancel: { text: "拒绝", effect: { 名声: -1 } },
      },
    },
    {
      id: "06",
      title: "书法练习",
      description: "不断练习书法可以修身养性",
      gameContent: "临摹字帖中的一个字，画出最相近的字",
      options: {
        confirm: { text: "接受" },
        cancel: { text: "拒绝", effect: { 名声: -1 } },
      },
    },
    {
      id: "07",
      title: "藏书阁整理",
      description: "被安排整理藏书阁被打乱的书籍",
      gameContent: "按特定规律将打乱的书籍归位",
      options: {
        confirm: { text: "接受" },
        cancel: { text: "拒绝", effect: { 名声: -1 } },
      },
    },
  ],
  county_hall: [
    {
      id: "01",
      title: "追击逃犯",
      description:
        "一名逃犯趁夜逃窜，县令下令追捕，面对眼前被冤枉的逃犯，是否帮助抓捕",
      options: {
        confirm: { text: "立即抓捕", effect: { 名声: 4, 金币: 2 } },
        cancel: { text: "协助逃犯逃跑", effect: { 名声: -1, 金币: -1 } },
      },
    },
    {
      id: "02",
      title: "税收征收",
      description:
        "一农户拒不缴纳税赋，县令下令追缴，看着瘦骨嶙峋的农户及妻儿，是否强制追缴",
      options: {
        confirm: { text: "拿走仅存的粮食", effect: { 名声: 4, 金币: 2 } },
        cancel: { text: "替农户交税", effect: { 名声: 1, 金币: -1 } },
      },
    },
    {
      id: "03",
      title: "民事调解",
      description:
        "村民之间因田地的划分问题引发两村械斗，县令下令平息，选择帮助哪边",
      options: [
        { text: "帮助石心村", effect: { 名声: 4, 智力: 2 } },
        { text: "帮助李家村", effect: { 名声: 4, 智力: 2 } },
        { text: "无能为力", effect: { 名声: -2 } },
      ],
    },
    {
      id: "04",
      title: "救援火灾",
      description: "一片住宅区发生火灾，县令下令扑灭灾情，是否救援",
      options: [
        { text: "全力灭火", effect: { 名声: 6, 金币: -5, 武力: 2 } },
        { text: "静待熄灭", effect: { 名声: -2 } },
      ],
    },
    {
      id: "05",
      title: "治安维护",
      description: "一伙蟊贼在闹市抢劫，县令下令剿灭，是否前往",
      options: [
        { text: "快速剿灭", effect: { 名声: 3, 金币: -2 } },
        { text: "观望不前", effect: { 名声: 1 } },
      ],
    },
  ],
  restaurant: {
    gameContent: "恢复体力",
  },
  inn: {
    gameContent: "恢复生命值",
  },
  clinic: {
    gameContent: "购买药品",
  },
  blacksmith: {
    gameContent: "武器打造",
  },
  market: {
    gameContent: "购买商品",
  },
};
