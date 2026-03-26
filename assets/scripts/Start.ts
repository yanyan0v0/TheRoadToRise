import { _decorator, Component, director, game, Node, sys } from 'cc';
const { ccclass, property } = _decorator;

// 微信小游戏API类型声明
declare const wx: {
    exitMiniProgram(options?: { success?: () => void; fail?: () => void; complete?: () => void }): void;
} | undefined;

// 抖音小游戏API类型声明
declare const tt: {
    exitMiniProgram(): void;
} | undefined;

@ccclass('Start')
export class Start extends Component {
    @property(Node)
    startButton: Node = null;

    @property(Node)
    exitButton: Node = null;

    start() {
        this.startButton.on(Node.EventType.TOUCH_END, () => {
            director.loadScene('SelectPlayerScene');
        });
        this.exitButton.on(Node.EventType.TOUCH_END, () => {
            this.exitGame();
        });
    }

    exitGame() {
        // 原生平台（PC/安卓/iOS）直接退出
        if (sys.isNative) {
            game.end();
        }
        // 微信小游戏
        else if (sys.platform === sys.Platform.WECHAT_GAME) {
            wx.exitMiniProgram();
        }
        // 抖音小游戏
        else if (sys.platform === sys.Platform.BYTEDANCE_MINI_GAME) {
            tt.exitMiniProgram();
        }
        // Web 网页（无法关闭，只能提示）
        else {
            alert("请手动关闭浏览器标签页");
        }
    }

    update(deltaTime: number) {
        
    }
}


