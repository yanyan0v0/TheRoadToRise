<!-- eslint-disable vue/multi-word-component-names -->
<template>
  <div class="container">
    <div class="content">
      <Icon type="md-arrow-round-back" @click="goBack" />
      <div class="title">{{ chapterInfo.name }}</div>
      <div class="chapter-desc">
        <div>
          <div class="ivu-description-term">书名：</div>
          <div class="ivu-description-detail">{{ chapterInfo.bookName }}</div>
        </div>
        <div>
          <div class="ivu-description-term">作者：</div>
          <div class="ivu-description-detail">{{ chapterInfo.authorName }}</div>
        </div>
        <div>
          <div class="ivu-description-term">本章字数：</div>
          <div class="ivu-description-detail">{{ chapterInfo.wordCount }}字</div>
        </div>
        <div>
          <div class="ivu-description-term">更新时间：</div>
          <div class="ivu-description-detail">{{ chapterInfo.time }}</div>
        </div>
      </div>
      <div class="text-container" v-html="chapterInfo.txtString"></div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { chapterStore } from '@/stores/chapter'
import type { Chapter } from 'env'
import { getCurrentInstance, reactive, type ComponentInternalInstance } from 'vue'
const { proxy } = getCurrentInstance() as ComponentInternalInstance

const store = chapterStore()
let chapterInfo: Chapter = reactive({})

try {
  const res = await store.getChapterById(proxy?.$route.params.id as string)
  chapterInfo = res.data
} catch (error) {
  console.error(error)
}

function goBack() {
  proxy?.$router.back()
}
</script>

<style lang="less" scoped>
.container {
  background-color: #ded9c5;
  color: #462e0b;
  height: 100%;

  .content {
    width: 950px;
    min-height: 100%;
    background-color: #f9f7ef;
    margin: 0 auto;
    box-shadow: 0 1px 8px 0 hsl(48deg 27% 82% / 40%);
    padding: 80px 90px;

    // 返回按钮
    .ivu-icon-md-arrow-round-back {
      position: absolute;
      left: -44px;
      font-size: 20px;
      background-color: rgba(70, 46, 11, 0.12);
      padding: 8px 12px;
      border-radius: 4px 0 0 4px;
      z-index: 1;
      cursor: pointer;
    }

    .title {
      font-size: 24px;
      line-height: 33px;
      font-weight: 500;
      margin-bottom: 20px;
    }

    .chapter-desc {
      display: flex;
      justify-content: space-between;
      font-size: 12px;

      & > div {
        display: flex;
      }
    }

    .text-container {
      margin-top: 50px;
      font-size: 14px;
      color: #515a6e;
    }
  }
}
</style>

<style>
.text-container > p {
  margin: 12px 0 0;
  text-indent: 2em;
}
</style>
