export default [
  {
    name: "云梦县",
    type: "city",
    position: {
      x: -380,
      y: 135,
      z: 0,
    },
    limit: {
      金币: 5,
    },
    success: {
      名望: 10,
    },
    fail: {
      体力: -5,
      生命力: -5,
    },
    description: "该地物产丰富，尤其铁矿最甚，因此催生出众多铁匠。",
    effect: [
      {
        name: "铁匠铺.武器.耐久",
        description: "铁匠铺武器耐久额外",
        value: 10
      },
      {
        name: "铁匠铺.武器.伤害",
        description: "铁匠铺武器伤害额外",
        value: 10
      },
    ],
  },
  {
    name: "泽上县",
    type: "city",
    position: {
      x: -260,
      y: 48,
      z: 0,
    },
    limit: {
      金币: 10,
    },
    success: {
      名望: 10,
    },
    fail: {
      体力: -10,
      生命力: -10,
    },
    description: "该地聚集了众多医馆，是世人的疗伤圣地。",
    effect: [
      {
        name: "医馆.生命力",
        description: "医馆治疗生命力额外",
        value: 10,
      },
      {
        name: "医馆.体质",
        description: "医馆治疗体质额外",
        value: 10,
      },
    ],
  },
  {
    name: "景阳冈",
    type: "tiger",
    position: {
      x: -10,
      y: 30,
      z: 0,
    },
    limit: {
      体力: 10,
    },
    success: {
      金币: 100,
    },
    fail: {
      体力: -10,
      生命力: -10,
    },
    description: "该地据说有大虫出没，急需英雄除害。",
    boss: {
      name: "大虫",
      description: "大虫出没，凶猛异常，据说已残害数名乡亲，需小心应对。",
      血量: 100,
      武力: 100,
      防御力: 50,
      阶段: [
        {
          name: "阶段1",
          description: "小心试探",
          伤害: 0.2,
        },
        {
          name: "阶段2",
          description: "愤怒出击",
          伤害: 0.4,
        },
        {
          name: "阶段3",
          description: "以命相搏",
          伤害: 1,
        },
      ]
    },
    effect: [
      {
        name: "体力",
        description: "体力",
        value: 1,
      },
    ],
  },
  {
    name: "日月潭",
    type: "scenery",
    position: {
      x: 173,
      y: 23,
      z: 0,
    },
    limit: {
      体力: 10,
      才智: 10,
    },
    success: {
      金币: 1000,
    },
    fail: {
      体力: -10,
      生命力: -10,
    },
    description: "景色优美，因两湖相依如日月而得名，传说湖底沉有宝藏。",
  },
  {
    name: "武陵县",
    type: "city",
    position: {
      x: 186,
      y: -138,
      z: 0,
    },
    limit: {
      金币: 10,
    },
    success: {
      名望: 10,
    },
    fail: {
      体力: -10,
      生命力: -10,
    },
    description: "该地崇尚武艺，是众多侠客的聚集地。",
    effect: [
      {
        name: "武馆.武力",
        description: "武馆武力额外",
        value: 10
      },
      {
        name: "武馆.体质",
        description: "武馆体质额外",
        value: 10
      },
    ],
  },
  {
    name: "泰山",
    type: "taoist",
    position: {
      x: 360,
      y: -200,
      z: 0,
    },
    limit: {
      体力: 10,
    },
    success: {
      武功秘籍: 1,
    },
    fail: {
      体力: -10,
      生命力: -10,
    },
    description: "泰山，五岳之首，雄伟壮丽，世外高人隐居之地。",
  },
];