import { _decorator, Component, director, Node } from 'cc';
const { ccclass, property } = _decorator;

@ccclass('SelectPlayer')
export class SelectPlayer extends Component {
    @property(Node)
    backButton: Node = null;
    @property(Node)
    confirmButton: Node = null;

    start() {
        // 返回按钮点击事件
        this.backButton.on(Node.EventType.TOUCH_START, () => {
            // 返回上一个场景
            director.loadScene('StartScene');
        });

        // 确认按钮点击事件
        this.confirmButton.on(Node.EventType.TOUCH_START, () => {
            // 确认选择并进入游戏场景
            director.loadScene('GameScene');
        });

    }

    update(deltaTime: number) {
        
    }
}


