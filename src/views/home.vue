<template>
  <div class="home-container full">
    <div v-if="showStartPage" class="center full">
      <button @click="showNote" class="home-start-btn">
        开始你的创造之旅吧
        <i class="iconfont icon-right"></i>
      </button>
    </div>
    <div v-else class="home-note-container full" contenteditable>
      <!-- <ul>
        <li v-for="index in maxLis" :key="index">
          <input :index="index" type="text" class="full" @keyup.enter="handleEnterClick(index)">
        </li>
      </ul> -->
      <div v-show="showTip" @click="setCommonWord" class="home-word-tip">
        <i class="iconfont icon-xin"></i>
        设为常用词
      </div>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      showStartPage: false,
      maxLis: 0,
      showTip: false,
      selectedWord: ''
    }
  },
  mounted() {
    if (!this.showStartPage) this.getLis()
  },
  methods: {
    showNote() {
      this.showStartPage = false
      this.$nextTick(() => {
        this.getLis()
      })
    },
    getLis() {
      // 获取容器高度
      const noteContainer = document.querySelector('.home-note-container')
      this.maxLis = Math.ceil((noteContainer.getBoundingClientRect().height - 20) / 30)

      // 记录刚鼠标开始按下时的位置 为了设置tip显示位置
      let startPoint = {};
      // 监听鼠标按下事件
      noteContainer.onmousedown =  (event) => {
        startPoint = {
          x: event.pageX,
          y: event.pageY,
        };
      };
      // 监听鼠标松开事件
      noteContainer.onmouseup =  (event) => {
        const tipDom = document.querySelector('.home-word-tip');
        // 判断是否是点击tip
        if (!tipDom.contains(event.target)) {
          let selectedWord = noteContainer.ownerDocument.getSelection().toString()
          // 判断是否选择文字
          if (selectedWord.length > 0) {
            // 比较结束位置的坐标与开始位置的坐标 为了让tip始终显示在选中文字的上面
            const x = event.pageX > startPoint.x ? startPoint.x : event.pageX;
            const y = event.pageY > startPoint.y ? startPoint.y : event.pageY;

            tipDom.style.top = `${y - 50}px`;
            tipDom.style.left = `${x}px`;
            this.showTip = true
            this.selectedWord = selectedWord
          } else {
            // 如果没有选择文字即隐藏
            this.showTip = false
          }
        }
      };
    },
    setCommonWord() {
      if (!this.$store.getters.isLogined) {
        console.log('登录弹窗')
        this.$store.commit('setLoginType', 1)
      } else {
        console.log(this.selectedWord)
      }
    },
    handleEnterClick(index) {
      document.querySelector(`input[index='${index + 1}']`).focus()
    }
  }
}
</script>

<style lang="less">
.home-container{
  .home-start-btn{
    border-radius: 26px;
    background-color: #4CAF50;
    color: #fff;
    border: none;
    padding: 16px 32px;;
    font-size: 18px;
  }
  .home-note-container{
    outline: none;
    overflow-y: auto;
    &>div{
        border-bottom: 1px solid #eee;

    }
    ul{
      padding: 10px 0;
      li{
        height: 30px;
        border-bottom: 1px solid #eee;
        input{
          border: none;
          font-size: 16px;
          &:focus{
            outline: none;
          }
        }
      }
    }
    .home-word-tip {
      position: absolute;
      top: 0;
      left: -13px;
      padding: 5px 8px;
      color: #464646;
      background-color: #fff;
      border-radius: 4px;
      box-shadow: 0 2px 12px #9e9e9e;
      font-size: 14px;
      cursor: pointer;
      .icon-xin{
        color: #ed4014;
        font-weight: bold;
      }
    }
    .home-word-tip::after {
      content: '';
      position: absolute;
      bottom: 0;
      left: 20%;
      width: 0;
      height: 0;
      transform: translateY(100%);
      border: 6px solid #fff;
      border-left-color: transparent;
      border-bottom-color: transparent;
      border-right-color: transparent;
    }
  }
}
</style>