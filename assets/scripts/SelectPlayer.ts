import {
  _decorator,
  Component,
  director,
  Label,
  Node,
  resources,
  Sprite,
  SpriteFrame,
  Animation,
  Prefab,
  instantiate,
  UITransform,
  Vec2,
} from "cc";
import ROLE_CONFIG from "./config/Role";
const { ccclass, property } = _decorator;

@ccclass("SelectPlayer")
export class SelectPlayer extends Component {
  @property(Node)
  backButton: Node = null;
  @property(Node)
  confirmButton: Node = null;
  @property(Node)
  selectRole: Node = null;
  @property(Node)
  selectButtons: Node = null;
  @property(Node)
  detailBox: Node = null;
  @property(Prefab)
  weaponTooltip: Prefab = null;

  private anim: Animation | null = null;

  onLoad() {
    this.showRoleDetail();
  }

  start() {
    // 返回按钮点击事件
    this.backButton.on(Node.EventType.TOUCH_START, () => {
      // 返回上一个场景
      director.loadScene("StartScene");
    });

    // 确认按钮点击事件
    this.confirmButton.on(Node.EventType.TOUCH_START, () => {
      // 播放动画
      this.anim = this.confirmButton.getComponent(Animation);
      this.anim.play();
      // 确认选择并进入游戏场景
      setTimeout(() => {
        director.loadScene("LineScene");
      }, 300);
    });

    // 选择按钮点击事件
    this.selectButtons.children.forEach(button => {
      button.on(Node.EventType.TOUCH_START, event => {
        // 显示角色详情
        this.showRoleDetail(event.target.name);
        // 取消其他选中
        this.selectButtons.children.forEach(button => {
          button.getChildByName("MiniBorder").active = true;
          button.getChildByName("MiniBorderSelected").active = false;
        });
        // 标记选中
        button.getChildByName("MiniBorder").active = false;
        event.target.getChildByName("MiniBorderSelected").active = true;
      });
    });
  }

  showRoleDetail(name = "WuKong") {
    const role = ROLE_CONFIG[name];
    if (role) {
      this.detailBox.active = true;
      // 显示角色大图
      resources.load(`select_player/${name.toLowerCase()}/spriteFrame`, SpriteFrame, (err, spriteFrame) => {
        if (err) {
          console.error(err);
          return;
        }
        this.selectRole.getChildByName("RoleBg").getComponent(Sprite).spriteFrame = spriteFrame;
      });
      // 显示角色名称
      this.detailBox.getChildByName("Name").getComponent(Label).string = role.name;
      // 显示角色描述
      this.detailBox
        .getChildByName("Attribute")
        .getChildByName("Hp")
        .getChildByName("Value")
        .getComponent(Label).string = role.attributes.生命值.toString();
      // 显示角色属性
      this.detailBox
        .getChildByName("Attribute")
        .getChildByName("Money")
        .getChildByName("Value")
        .getComponent(Label).string = role.attributes.金币.toString();
      // 显示角色武器
      const weaponsNode = this.detailBox.getChildByName("Weapon");
      [0, 1].forEach(index => {
        const weapon = role.weapons[index];
        const weaponNode = weaponsNode.getChildByName(`Weapon${index + 1}`);
        if (!weapon) {
          weaponNode.active = false;
          return;
        }
        weaponNode.active = true;
        // 加载武器图片
        resources.load(`weapon/${weapon.key}/spriteFrame`, SpriteFrame, (err, spriteFrame) => {
          if (err) {
            console.error(err);
            return;
          }
          weaponNode.getComponent(Sprite).spriteFrame = spriteFrame;
        });

        let weaponTooltip = null;
        if (!weaponTooltip) {
          weaponTooltip = instantiate(this.weaponTooltip);
          weaponNode.addChild(weaponTooltip);
          weaponTooltip.setPosition(0, 0);
          weaponTooltip.getComponent(UITransform).anchorPoint = new Vec2(0, 0);
        }
        // 给武器注册悬浮事件
        weaponNode.on(Node.EventType.TOUCH_START, () => {
          // 显示武器信息
          weaponTooltip.active = true;
        });
      });
    }
  }

  update(deltaTime: number) {}
}
