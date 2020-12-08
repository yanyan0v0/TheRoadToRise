<template>
  <div v-show="loginType" class="login-dialog-mask">
    <div class="login-dialog">
      <i class="iconfont icon-close" @click="hideLogin"></i>
      <div v-show="loginType === 1" class="login-dialog-content">
        <p class="login-title">您还未登录</p>
        <p class="login-tips">(请先登录/注册再进行操作)</p>
        <button class="login-btn" @click="toLogin">登录</button>
        <a class="register-a" @click="toRegister">注册</a>
      </div>
      <div v-show="loginType === 2" class="login-dialog-content">
        <y-form label-width="80px">
          <y-form-item label="用户名">
            <y-input type="text"></y-input>
          </y-form-item>
          <y-form-item label="密码">
            <y-input type="text"></y-input>
          </y-form-item>
          <div class="text-center">
            <y-button color="primary" @click="login">登录</y-button>
          </div>
        </y-form>
      </div>
      <div v-show="loginType === 3" class="login-dialog-content">
        <y-form label-width="80px">
          <y-form-item label="用户名">
            <y-input type="text"></y-input>
          </y-form-item>
          <y-form-item label="密码">
            <y-input type="text"></y-input>
          </y-form-item>
          <y-button color="primary" @click="register">注册</y-button>
        </y-form>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  computed: {
    loginType() {
      return this.$store.state.loginType
    }
  },
  methods: {
    hideLogin() {
      this.$store.commit('setLoginType', 0)
    },
    toLogin() {
      this.$store.commit('setLoginType', 2)
    },
    toRegister() {
      this.$store.commit('setLoginType', 3)
    },
    login() {
      this.$store.commit('user', {
        name: 'yanyan'
      })
      this.hideLogin()
    },
    register() {
      this.$store.commit('user', {
        name: 'yanyan'
      })
      this.hideLogin()
    }
  }
}
</script>

<style lang="less">
.login-dialog-mask{
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 100;
  background-color: rgba(0,0,0,.3);
  .login-dialog{
    position: relative;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    width: 300px;
    border-radius: 4px;
    background-color: #fff;
    .icon-close{
      position: absolute;
      top: 10px;
      right: 10px;
      cursor: pointer;
    }
    .login-dialog-content{
      padding: 20px;
      .login-title{
        font-size: 24px;
        text-align: center;
        margin: 40px 0 10px;
      }
      .login-tips{
        font-size: 14px;
        color: #aaa;
        text-align: center;
      }
      .login-btn{
        display: block;
        margin: 20px 0;
        padding: 10px 20px;
        width: 100%;
        font-size: 18px;
        border-radius: 25px;
        color: #fff;
        background-color: red;
      }
      .register-a{
        display: block;
        width: 100%;
        color: #03A9F4;
        text-align: center;
      }
    }
  }
}
</style>