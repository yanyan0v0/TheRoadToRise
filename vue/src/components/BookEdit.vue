<template>
  <div class="book">
    <ul class="book-ul">
      <li class="book-li" v-for="book in bookList" :key="book.id">
        <div class="book-li__left">
          <img class="book-cover" src="@/assets/imgs/book-cover.jpg" alt="" srcset="" />
          <div>
            <p class="book-title">{{ book.name }}</p>
            <div class="book-type">
              <Tag type="border" v-for="typeName in book.type" :key="typeName">{{ typeName }}</Tag>
            </div>
            <p class="book-count">{{ bookWordCount(book) }}万字</p>
            <p class="book-desc" v-line-clamp="2">{{ book.description }}</p>
          </div>
        </div>
        <div class="book-li__right">
          <Button type="primary">编辑</Button>
        </div>
      </li>
    </ul>
  </div>
</template>

<script setup lang="ts">
import type { Book } from 'env'
import { computed, reactive } from 'vue'

const bookList = reactive([
  {
    id: 1,
    name: '外星人的毕业设计',
    type: ['科幻', '未来'],
    state: 1,
    wordCount: 1561,
    reader: 1,
    authorId: 1,
    description:
      '90后慢慢地在接过80后的枪登上属于他们的时代，但70后、80后、90后之间的矛盾也在凸显，而国企在时代的变革中面对变化巨大的信息时代，又当何去何从，这给了我们思考。我们都说90后是叛逆的一代，这或许不对，他们依然有他们的思维方式，他们的做事准则，当80后将企业的重担移交给他们，他们会用什么方式去传承？李小白一个90后的中石油员工，他将在国企从一个人见人恨的老鼠屎成长为合格管理者，这一路很难。',
  },
])

const bookWordCount = computed(() => (book: Book) => ((book.wordCount || 0) / 10000).toFixed(2))
</script>

<style lang="less" scoped>
.book {
  &-ul {
    border-bottom: 1px solid #ccc;
  }
  &-li {
    display: flex;
    justify-content: space-between;
    padding: 10px 0;
    &__left {
      display: flex;
      flex: 1;
      .book-cover {
        width: 116px;
        height: 180px;
        border-radius: 4px;
        margin-right: 10px;
      }
      .book-title {
        font-size: 18px;
        font-weight: bold;
      }
      .book-desc {
        margin-top: 20px;
        font-size: 14px;
        color: rgba(0, 0, 0, 0.6);
      }
      .book-count {
        margin-top: 10px;
        color: #2196f3;
        font-weight: bold;
      }
    }

    &__right {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 100px;
    }
  }
}
</style>
