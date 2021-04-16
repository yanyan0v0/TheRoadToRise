<template>
  <div id="app">
    <header>
      <img class="logo" src="./assets/logo.png" />
      <ul class="menu">
        <li>首页</li>
      </ul>
      <div class="avatar" v-if="isLogined">
        <img src="./assets/logo.png" alt="" srcset="">
        <div class="avatar-right">
          <p class="nickname">yanyan</p>
          <span class="level">lv 1</span>
        </div>
      </div>
      <div v-else class="header-login" @click="login">登录</div>
    </header>
    <div class="container">
      <router-view />
    </div>
    <login-dialog></login-dialog>
  </div>
</template>

<script>
export default {
  name: 'App',
  components: {
    'login-dialog': () => import('@/components/login')
  },
  computed: {
    isLogined() {
      return this.$store.getters.isLogined
    }
  },
  methods: {
    login() {
      this.$store.commit('setLoginType', 2)
    }
  }
}
</script>

<style lang="less">
#app{
  display: flex;
  flex-direction: column;
  position: relative;
  width: 100%;
  height: 100%;
  overflow: hidden;
  header{
    display: flex;
    justify-content: space-between;
    height: 50px;
    padding: 5px 10%;
    background-color: #393D49;
    color: #fff;
    .logo{
      height: 50px;
    }
    .menu{
      display: flex;
      flex: 1;
      margin: 0 20px;
      li{
        line-height: 40px;
      }
    }
    .avatar{
      display: flex;
      img{
        width: 50px;
        height: 50px;
        border-radius:50%;
      }
      .avatar-right{
        margin: 5px;
        font-size: 14px;
      }
    }
    .header-login{
      line-height: 40px;
      cursor: pointer;
    }
  }
  .container{
    flex: 1;
    width: 80%;
    margin: 0 auto;
  }
}
</style>
