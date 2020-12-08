import Vue from 'vue'
import Vuex from 'vuex'
Vue.use(Vuex)

import { getSessionItem, setSessionItem, getLocalItem, setLocalItem } from '@/util/tools'

export default new Vuex.Store({
  state: {
    // 登录弹窗类型 0: 不显示  1: 提示登录注册  2: 直接登录  3: 直接注册
    loginType: 0,
    // 当前登录用户
    user: {},
    // 当前激活的菜单
    activeMenu: getSessionItem('activeMenu') || {},
  },
  getters: {
    isLogined(state) {
      return Boolean(state.user.name)
    }
  },
  mutations: {
    setLoginType(state, type) {
      state.loginType = type
    },
    setUser(state, user) {
      state.user = user
      setSessionItem('user', user)
    },
    setActiveMenu(state, menu) {
      state.activeMenu = menu
      setSessionItem('activeMenu', menu)
    },
  },
  actions: {
    //
  },
  modules: {
    //
  }
})
