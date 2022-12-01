<template>
  <div class="container">
    <div class="header">
      <div class="book">
        <img class="book-cover" src="@/assets/imgs/book-cover.jpg" />
        <div class="book-info">
          <div>
            <div class="book-title">外星人的毕业设计</div>
            <Tag color="cyan">更新中</Tag>
            <div class="book-type">
              <Tag type="border">科幻</Tag>
            </div>
            <div class="book-count">
              <span class="book-count__word">0.1</span>
              <span>万字</span>
              <Divider type="vertical" />
              <span>1人在读</span>
            </div>
            <div class="book-chapter">
              <span>最近更新：{{ chapterList[chapterList.length - 1] }} </span>
              <span class="book-chapter__time">2021-03-21 20:22</span>
            </div>
          </div>
          <Button type="warning" shape="circle">开始阅读</Button>
        </div>
      </div>
      <Divider v-height="200" type="vertical" />
      <div class="book-author">
        <img class="author-avatar" src="@/assets/imgs/default-avatar.png" />
        <p class="author-name">笔先声</p>
        <p class="author-desc">
          我叫笔先声，我是网络作家，希望我们一路相伴，不离不弃。
        </p>
      </div>
    </div>
    <div class="content">
      <div class="section">
        <div class="section-header">作品简介</div>
        <div class="section-content">
          90后慢慢地在接过80后的枪登上属于他们的时代，但70后、80后、90后之间的矛盾也在凸显，而国企在时代的变革中面对变化巨大的信息时代，又当何去何从，这给了我们思考。
          我们都说90后是叛逆的一代，这或许不对，他们依然有他们的思维方式，他们的做事准则，当80后将企业的重担移交给他们，他们会用什么方式去传承？李小白一个90后的中石油员工，他将在国企从一个人见人恨的老鼠屎成长为合格管理者，这一路很难。
        </div>
      </div>
      <div class="section">
        <div class="section-header">目录·{{ chapterList.length }}章</div>
        <div class="section-content">
          <Row class="chapter-container">
            <Col class="chapter" v-for="chapter in chapterList" :key="chapter" :xs="24" :sm="24" :md="12" :lg="6">
            {{ chapter }}
            </Col>
          </Row>
        </div>
      </div>
    </div>
  </div>
</template>
<script lang="ts" setup>
import { reactive } from 'vue'
const chapterList = reactive(['第1章 开始', '第2章 结束', '第3章 再来'])
</script>
<style lang="less" scoped>
.container {
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: content-box;
  background-color: #f6f6f6;

  .header {
    display: flex;
    width: 100%;
    padding: 20px 10%;
    justify-content: space-between;
    align-items: center;
    background-color: #fff;

    .book {
      display: flex;
      margin-right: 50px;

      &-info {
        display: flex;
        flex-direction: column;
        justify-content: space-between;
      }

      &-cover {
        height: 234px;
        width: 180px;
        border-radius: 8px;
        margin-right: 20px;
      }

      &-title {
        display: inline-block;
        margin-top: 10px;
        margin-right: 10px;
        height: 32px;
        line-height: 32px;
        font-size: 24px;
        font-weight: 500;
      }

      &-count {
        margin: 10px 0 20px;
        color: rgba(0, 0, 0, 0.4);
        font-size: 12px;

        &__word {
          color: rgba(0, 0, 0, 1);
          font-size: 24px;
          line-height: 28px;
          margin-right: 8px;
        }
      }

      &-chapter {
        font-size: 12px;

        &__time {
          margin-left: 10px;
        }
      }

      &-author {
        margin: 0 50px;
        text-align: center;

        .author-avatar {
          border-radius: 50%;
          border: 1px solid #f1f1f1;
          width: 70px;
          height: 70px;
        }

        .author-name {
          font-size: 22px;
          height: 30px;
          line-height: 30px;
          margin-top: 12px;
        }

        .author-desc {
          margin: 8px auto 0;
          font-size: 12px;
          line-height: 17px;
          width: 174px;
          color: rgba(0, 0, 0, 0.4);
          overflow: hidden;
          text-overflow: ellipsis;
          display: -webkit-box;
        }
      }
    }
  }

  .content {
    background-color: #fff;
    margin: 20px auto;
    padding: 20px;
    width: 80%;
    flex: 1;

    .section {
      &-header {
        padding-bottom: 10px;
        font-size: 24px;
        color: rgba(0, 0, 0, 0.85);
        font-weight: 500;
        border-bottom: 1px solid rgba(0, 0, 0, 0.1);
      }

      &-content {
        margin: 30px 0;
        padding: 0 30px;
        font-size: 16px;
        line-height: 24px;
        color: #666;
        overflow: hidden;
        text-overflow: ellipsis;
        display: -webkit-box;
        -webkit-line-clamp: 3;
        -webkit-box-orient: vertical;
      }
    }
  }
}
</style>
