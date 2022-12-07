import { defineStore } from 'pinia'
import { reactive } from 'vue'

export const userStore = defineStore('user', () => {
  const defaultUser = reactive({
    id: 1,
    name: '笔先声',
    authorId: 1,
  })
  return defaultUser
})
