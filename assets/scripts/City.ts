import {
  _decorator,
  Component,
  Label,
  Node,
  resources,
  Sprite,
  SpriteFrame,
  UITransform,
  Vec3,
} from "cc";
const { ccclass, property } = _decorator;
import City01 from "./config/city_mock/City01";
import CityEvent from "./config/random/CityEvent";
const cardSpriteFrameMap = new Map();

@ccclass("City")
export class City extends Component {
  @property(Node)
  cityNode: Node = null;
  start() {
    // 给每个节点添加单色精灵
    City01.forEach((item) => {
      const node = new Node(item.name);
      node.setPosition(new Vec3(item.position.x, item.position.y, 0));
      // 给node设置大小
      node.addComponent(UITransform).setContentSize(200, 200);
      // 给node添加点击事件
      node.on(Node.EventType.TOUCH_END, () => {
        // 判断是否发生随机事件
        const isRandom = Math.random() > 0.5;
        if (isRandom) {
          // 发生随机事件 从CityEvent中随机获取一个事件
          const randomEvent = CityEvent[item.type][Math.floor(Math.random() * CityEvent[item.type].length)];
        }
        // 控制事件页面的显示与隐藏
        const cardContainer = this.cityNode.children.find(
          (item) => item.name === "CardContainer",
        );
        if (cardContainer) {
          cardContainer.active = !cardContainer.active;
          const cardMask = cardContainer.children.find(
            (item) => item.name === "Mask",
          );
          if (cardMask) {
            // 给cardMask添加点击关闭事件
            cardMask.on(Node.EventType.TOUCH_END, () => {
              cardContainer.active = false;
            });
          }
          const card = cardContainer.children.find(
            (item) => item.name === "Card",
          );
          if (card) {
            // 避免重复加载设置缓存
            if (cardSpriteFrameMap.has(item.type)) {
              card.getComponent(Sprite).spriteFrame = cardSpriteFrameMap.get(
                item.type,
              );
            } else {
              resources.load(
                `card/${item.type}/spriteFrame`,
                SpriteFrame,
                (err, spriteFrame) => {
                  if (err) {
                    console.error("加载 SpriteFrame 失败：", err);
                    return;
                  }
                  cardSpriteFrameMap.set(item.type, spriteFrame);
                  // 给节点设置 SpriteFrame
                  card.getComponent(Sprite).spriteFrame = spriteFrame;
                },
              );
            }
            card.children.forEach((label) => {
              switch (label.name) {
              }
            });
          }
        }
      });
      this.cityNode.addChild(node);
    });
  }

  update(deltaTime: number) {}
}
