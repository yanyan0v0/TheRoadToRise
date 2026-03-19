import { _decorator, Component, director, Node } from 'cc';
const { ccclass, property } = _decorator;

@ccclass('Start')
export class Start extends Component {
    @property(Node)
    startButton: Node = null;

    start() {
        this.startButton.on(Node.EventType.TOUCH_START, () => {
            director.loadScene('SelectPlayerScene');
        });
    }

    update(deltaTime: number) {
        
    }
}


