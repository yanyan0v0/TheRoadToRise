<template>
  <div class="container">
    <div v-if="userStore.authorId" class="content">
      <Menu class="content-menu" :active-name="menuAction">
        <MenuGroup title="内容管理">
          <MenuItem name="authorBook">
            <Icon type="md-document" />
            书籍管理
          </MenuItem>
          <MenuItem name="2">
            <Icon type="md-chatbubbles" />
            评论管理
          </MenuItem>
        </MenuGroup>
        <MenuGroup title="统计分析">
          <MenuItem name="3">
            <Icon type="md-heart" />
            用户留存
          </MenuItem>
          <MenuItem name="4">
            <Icon type="md-leaf" />
            流失用户
          </MenuItem>
        </MenuGroup>
      </Menu>
      <div class="content-view">
        <RouterView />
      </div>
    </div>
    <template v-else>
      <a href="">成为作家</a>
    </template>
  </div>
</template>

<script setup lang="ts">
import { getCurrentInstance, ref, onMounted, type ComponentInternalInstance } from 'vue'
import { userStore as userStoreInstance } from '@/stores/user'
const { proxy } = getCurrentInstance() as ComponentInternalInstance
const userStore = userStoreInstance()

const menuAction = ref('authorBook')

onMounted(() => {
  proxy?.$router.replace({ name: menuAction.value })
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

  .content {
    display: flex;
    background-color: #fff;
    margin: 20px auto;
    padding: 20px;
    width: 80%;
    flex: 1;
    overflow-y: auto;

    &-menu {
      height: 100%;
    }
    &-view {
      flex: 1;
      padding: 0 20px;
    }
  }
}
</style>
