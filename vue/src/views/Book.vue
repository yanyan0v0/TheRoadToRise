<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <div class="container">
    <div class="header">
      <div class="book">
        <img class="book-cover" src="@/assets/imgs/book-cover.jpg" />
        <div class="book-info">
          <div>
            <div class="book-title">{{ book.name }}</div>
            <Tag class="book-state" color="cyan">{{ bookStateName }}</Tag>
            <div class="book-type">
              <Tag type="border" v-for="typeName in book.type" :key="typeName">{{ typeName }}</Tag>
            </div>
            <div class="book-count">
              <span class="book-count__word">{{ bookWordCount }}</span>
              <span>万字</span>
              <Divider type="vertical" />
              <span>{{ book.reader }}人在读</span>
            </div>
            <div class="book-chapter">
              <span>最近更新：{{ newestChapter.name }} </span>
              <span class="book-chapter__time">{{ newestChapter.time }}</span>
            </div>
          </div>
          <Button type="warning" shape="circle">开始阅读</Button>
        </div>
      </div>
      <Divider v-height="200" type="vertical" />
      <div class="book-author">
        <img class="author-avatar" src="@/assets/imgs/default-avatar.png" />
        <p class="author-name">
          <Tag :color="author.gender === '男' ? 'blue' : 'magenta'"
            ><Icon :type="author.gender === '男' ? 'md-male' : 'md-female'"
          /></Tag>
          {{ author.name }}
        </p>
        <p class="author-desc">{{ author.introduce }}</p>
      </div>
    </div>
    <div class="content custom-scrollbar">
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
            <Col class="chapter" v-for="chapter in chapterList" :key="chapter.id" :sm="24" :md="12" :lg="6">
              <RouterLink :to="`/book/${chapter.bookId}/chapter/${chapter.id}`">{{ chapter.name }}</RouterLink>
            </Col>
          </Row>
        </div>
      </div>
    </div>
  </div>
</template>
<script lang="ts" setup>
import { computed, getCurrentInstance, reactive, type ComponentInternalInstance } from 'vue'
import { chapterStore as chapterStoreInstance } from '@/stores/chapter'
import { bookStore as bookStoreInstance } from '@/stores/book'
import { authorStore as authorStoreInstance } from '@/stores/author'
import { BOOK_STATE } from '@/utils/enum'
import type { Author, Book, Chapter } from 'env'
const chapterStore = chapterStoreInstance()
const bookStore = bookStoreInstance()
const authorStore = authorStoreInstance()
const { proxy } = getCurrentInstance() as ComponentInternalInstance

let book: Book = reactive({})
let author: Author = reactive({})
let chapterList: Chapter[] = reactive([])

try {
  let res = await bookStore.getBookById(proxy?.$route.params.bookId as string)
  book = res.data

  res = await authorStore.getAuthorByBookId(proxy?.$route.params.bookId as string)
  author = res.data

  res = await chapterStore.getChapterListByBookId(proxy?.$route.params.bookId as string)
  chapterList = res.data

  book.wordCount = chapterList.map((item) => item.wordCount).reduce((total = 0, count = 0) => total + count)
} catch (error) {
  console.error(error)
}

const newestChapter = computed(() => chapterList[chapterList.length - 1])
const bookWordCount = computed(() => ((book.wordCount || 0) / 10000).toFixed(2))
const bookStateName = computed(() => {
  switch (book.state) {
    case BOOK_STATE.FINISHED:
      return '已完结'
    case BOOK_STATE.UPDATING:
      return '更新中'
    default:
      return '未发布'
  }
})
</script>
<style lang="less" scoped>
.container {
  display: flex;
  flex-direction: column;
  height: 100%;
  background-color: #f6f6f6;
  overflow-y: hidden;
  padding-top: 74px;

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

      &-state {
        vertical-align: bottom;
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

          & > .ivu-tag {
            vertical-align: bottom;
          }
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
    overflow-y: auto;

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
        .chapter {
          line-height: 32px;
          font-size: 14px;
          & > a {
            color: rgba(0, 0, 0, 0.9);
          }
        }
      }
    }
  }
}
</style>
