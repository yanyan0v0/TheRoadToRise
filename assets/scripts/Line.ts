import { _decorator, Component, director, Label, Node, resources, Sprite, SpriteFrame, UITransform, Vec3 } from "cc";
const { ccclass, property } = _decorator;
import Line01 from "./config/line_mock/Line01";
const cardSpriteFrameMap = new Map<string, SpriteFrame>();

@ccclass("Line")
export class Line extends Component {
  @property(Node)
  lineNode: Node = null;
  start() {
    // 给每个节点添加单色精灵
    Line01.forEach(item => {
      const node = new Node(item.name);
      node.setPosition(new Vec3(item.position.x, item.position.y, 0));
      // 给node设置大小
      node.addComponent(UITransform).setContentSize(100, 100);
      // 给node添加点击事件
      node.on(Node.EventType.TOUCH_END, () => {
        // 控制卡牌的显示与隐藏
        const cardContainer = this.lineNode.getChildByName("CardContainer");
        if (cardContainer) {
          cardContainer.active = !cardContainer.active;
          const cardMask = cardContainer.getChildByName("Mask");
          if (cardMask) {
            // 给cardMask添加点击关闭事件
            cardMask.on(Node.EventType.TOUCH_END, () => {
              cardContainer.active = false;
            });
          }
          const card = cardContainer.getChildByName("Card");
          if (card) {
            // 避免重复加载设置缓存
            if (cardSpriteFrameMap.has(item.type)) {
              card.getComponent(Sprite).spriteFrame = cardSpriteFrameMap.get(item.type);
            } else {
              resources.load(`card/${item.type}/spriteFrame`, SpriteFrame, (err, spriteFrame) => {
                if (err) {
                  console.error("加载 SpriteFrame 失败：", err);
                  return;
                }
                cardSpriteFrameMap.set(item.type, spriteFrame);
                // 给节点设置 SpriteFrame
                card.getComponent(Sprite).spriteFrame = spriteFrame;
              });
            }
            card.children.forEach(label => {
              switch (label.name) {
                case "Name":
                  label.getComponent(Label).string = item.name;
                  break;
                case "Limit":
                  // limit转为字符串 字段名 > 字段值
                  const limit = Object.keys(item.limit)
                    .map(key => {
                      return `${key}>${item.limit[key]}`;
                    })
                    .join("\n");
                  label.getComponent(Label).string = limit;
                  break;
                case "Success":
                  const success = Object.keys(item.success)
                    .map(key => {
                      return `${key}+${item.success[key]}`;
                    })
                    .join("\n");
                  label.getComponent(Label).string = success;
                  break;
                case "Description":
                  label.getComponent(Label).string = item.description;
                  break;
              }
            });

            card.on(Node.EventType.TOUCH_END, () => {
              director.loadScene("CityScene");
            });
          }
        }
      });
      this.lineNode.addChild(node);
    });
  }

  update(deltaTime: number) {}
}
