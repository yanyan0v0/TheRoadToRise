<template>
  <div class="app-container">
    <header v-if="!hideHeader" class="app-header">
      <div class="app-header--left">
        <img class="app-header__logo" src="@/assets/imgs/logo.png" alt="" srcset="" />
        <Menu class="app-header__menu" mode="horizontal" :active-name="menuAction" @on-select="menuSelect">
          <MenuItem v-for="menu in menuItems" :name="menu.name" :key="menu.name">
            {{ menu.title }}
          </MenuItem>
        </Menu>
      </div>
      <div class="app-header--right">
        <Input class="app-header__search" search placeholder="输入书籍名" />
        <Avatar src="/src/assets/imgs/default-avatar.png" size="large" />
      </div>
    </header>
    <Suspense>
      <RouterView />
      <template #fallback> Loading... </template>
    </Suspense>
  </div>
</template>

<script setup lang="ts">
import { getCurrentInstance, onMounted, reactive, ref, watchEffect, type ComponentInternalInstance } from 'vue'
import { RouterView } from 'vue-router'
const { proxy } = getCurrentInstance() as ComponentInternalInstance

let menuItems: { name: string; title: string }[] = reactive([])
const menuAction = ref('home')
const hideHeader = ref(true)

const menuSelect = function (menuName: string) {
  console.log(menuName)
  proxy?.$router.replace({ name: menuName })
}

onMounted(() => {
  const menuRouters = proxy?.$router.getRoutes().filter((item) => item.meta.title) || []
  menuItems.push(
    ...menuRouters.map((item) => ({
      name: item.name as string,
      title: item.meta.title as string,
    }))
  )
})

watchEffect(() => {
  // 页面刷新后对应菜单栏要显示激活状态
  const currentRoute = proxy?.$route
  console.log(currentRoute)
  if (currentRoute?.name) {
    const currentMenu = menuItems.find((item) => item.title === currentRoute?.meta.title)
    if (currentMenu) {
      menuAction.value = currentMenu.name
    }

    hideHeader.value = Boolean(currentRoute?.meta.hideHeader)
  }
})
</script>

<style lang="less" scoped>
.app {
  &-container {
    height: 100%;
    width: 100%;
  }

  &-header {
    position: fixed;
    display: flex;
    justify-content: space-between;
    height: 64px;
    width: 100%;
    padding: 0 10%;
    background-color: #fff;
    z-index: 100;
    &--left,
    &--right {
      display: flex;
      align-items: center;
    }
    &__logo {
      height: 100%;
    }
    &__menu {
      padding: 0 40px;
      &::after {
        display: none !important;
      }
      & > .ivu-menu-item {
        padding: 0 10px;
        margin: 0 10px;
      }
    }
    &__search {
      flex: 1;
      margin-right: 20px;
    }
  }
}
</style>
