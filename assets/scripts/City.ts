import { _decorator, Button, Component, Node, resources, Sprite, SpriteFrame, UITransform, Vec3 } from "cc";
const { ccclass, property } = _decorator;
import City01 from "./config/city_mock/City01";
import CityEvent, { RandomEvent } from "./config/random/CityEvent";
const layerSpriteFrameMap = new Map<string, SpriteFrame>();

@ccclass("City")
export class City extends Component {
  @property(Node)
  cityNode: Node = null;

  private layerType: string = "";
  private randomEvent: RandomEvent = null;
  start() {
    // 获取弹出层
    const layerNode = this.cityNode.getChildByName("Layer");
    console.log("layerNode", layerNode);

    // 给每个节点添加单色精灵
    City01.forEach(item => {
      const node = new Node(item.name);
      node.setPosition(new Vec3(item.position.x, item.position.y, 0));
      // 给node设置大小
      node.addComponent(UITransform).setContentSize(200, 200);
      // 给node添加点击事件
      node.on(Node.EventType.TOUCH_END, () => {
        layerNode.active = true;
        // 提升层级
        layerNode.setSiblingIndex(999);
        this.layerType = item.type;
        this.showLayerButtons(layerNode);
        // 判断是否发生随机事件
        const isRandom = ["school", "county_hall"].includes(item.type);
        if (isRandom) {
          // 发生随机事件 从CityEvent中随机获取一个事件
          this.randomEvent = CityEvent[item.type][Math.floor(Math.random() * CityEvent[item.type].length)];

          // 判断缓存
          if (layerSpriteFrameMap.has(`${item.type}${this.randomEvent.id}`)) {
            layerNode.getComponent(Sprite).spriteFrame = layerSpriteFrameMap.get(`${item.type}${this.randomEvent.id}`);
          } else {
            // 获取对应背景图
            resources.load(`${item.type}/case${this.randomEvent.id}/spriteFrame`, SpriteFrame, (err, spriteFrame) => {
              if (err) {
                console.error("加载 SpriteFrame 失败：", err);
                return;
              }
              // 给节点设置 SpriteFrame
              layerNode.getComponent(Sprite).spriteFrame = spriteFrame;

              layerSpriteFrameMap.set(`${item.type}${this.randomEvent.id}`, spriteFrame);
            });
          }
        }
      });
      this.cityNode.addChild(node);
    });
  }

  showLayerButtons(layerNode: Node) {
    switch (this.layerType) {
      case "school":
        this.showSchoolButtons(layerNode);
        break;
      case "county_hall":
        this.showCountyHallButtons(layerNode);
        break;
      default:
        break;
    }
  }

  showCountyHallButtons(layerNode: Node) {
    console.log("showCountyHallButtons");
    layerNode.getChildByName("SchoolNode").active = false;
    const countyHallNode = layerNode.getChildByName("CountyHallNode");
    countyHallNode.active = true;
    const confirmNode = countyHallNode.getChildByName("Option1");
    const cancelNode = countyHallNode.getChildByName("Option2");
    // 判断是否给按钮添加点击事件
    if (!confirmNode.getComponent(Button).clickEvents.length) {
      confirmNode.on(Node.EventType.TOUCH_END, () => {
        console.log("confirm");
      });
    }
    if (!cancelNode.getComponent(Button).clickEvents.length) {
      cancelNode.on(Node.EventType.TOUCH_END, () => {
        layerNode.active = false;
      });
    }
  }

  showSchoolButtons(layerNode: Node) {
    console.log("showSchoolButtons");
    layerNode.getChildByName("CountyHallNode").active = false;
    const schoolNode = layerNode.getChildByName("SchoolNode");
    schoolNode.active = true;
    const confirmNode = schoolNode.getChildByName("Confirm");
    const cancelNode = schoolNode.getChildByName("Cancel");
    // 判断是否给按钮添加点击事件
    confirmNode.on(Node.EventType.TOUCH_END, () => {
      console.log("confirm");
      confirmNode.off(Node.EventType.TOUCH_END);
    });
    cancelNode.on(Node.EventType.TOUCH_END, () => {
      layerNode.active = false;
      cancelNode.off(Node.EventType.TOUCH_END);
    });
  }

  update(deltaTime: number) {}
}
