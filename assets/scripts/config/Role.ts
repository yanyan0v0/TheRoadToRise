const ROLE_CONFIG = {
  WuKong: {
    name: "孙悟空",
    description: "这是孙悟空的描述",
    attributes: {
      生命值: 80,
      金币: 80,
    },
    weapons: [
      {
        key: "jingubang",
        name: "金箍棒",
        attribute: {
          攻击: 5,
        },
        description: "攻击+5",
      },
      {
        key: "jindouyun",
        name: "筋斗云",
        attribute: {
          防御: 5,
        },
        description: "防御+5",
      },
    ],
  },
  BaJie: {
    name: "猪八戒",
    description: "这是猪八戒的描述",
    attributes: {
      生命值: 100,
      金币: 80,
    },
    weapons: [
      {
        key: "jiuzhidingpa",
        name: "九齿钉耙",
        attribute: {
          防御: 5,
        },
        description: "防御+5",
      },
    ],
  },
  ShaSeng: {
    name: "沙僧",
    description: "这是沙僧的描述",
    attributes: {
      生命值: 80,
      金币: 200,
    },
    weapons: [
      {
        key: "jiangyaobaochan",
        name: "降妖宝铲",
        attribute: {
          金币: 5,
        },
        description: "金币+5",
      },
    ],
  },
  SanZang: {
    name: "唐三藏",
    description: "这是唐三藏的描述",
    attributes: {
      生命值: 60,
      金币: 60,
    },
    weapons: [
      {
        key: "jiuhuanxizhang",
        name: "九环锡杖",
        attribute: {
          生命: 5,
        },
        description: "生命+5",
      },
      {
        key: "bailongma",
        name: "白龙马",
        attribute: {
          速度: 5,
        },
        description: "速度+5",
      },
    ],
  },
};

export default ROLE_CONFIG;
