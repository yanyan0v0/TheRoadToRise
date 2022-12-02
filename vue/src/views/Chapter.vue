<template>
  <div class="container">
    <div class="content">
      <div class="title">第1章 开始</div>
      <DescriptionList :col="4">
        <Description term="书名：">外星人的毕业设计 </Description>
        <Description term="作者：">笔先声 </Description>
        <Description term="本章字数：">2155字 </Description>
        <Description term="更新时间：">2020/12/01 15:56 </Description>
      </DescriptionList>
      <div class="text-container">124235435</div>
    </div>
  </div>
</template>

<script setup lang="ts"></script>

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
    .title {
      font-size: 24px;
      line-height: 33px;
      font-weight: 500;
      margin-bottom: 20px;
    }
    .ivu-description-list {
      font-size: 12px;
    }
    .text-container {
      margin-top: 50px;
      font-size: 14px;
    }
  }
}
</style>
