import { getCurrentInstance, type ComponentInternalInstance } from 'vue'
import { defineStore } from 'pinia'
import URL from '@/utils/url'
import type { DefaultResponse } from 'env'

export const bookStore = defineStore('book', () => {
  const { proxy } = getCurrentInstance() as ComponentInternalInstance

  async function getBookById(bookId: number | string): Promise<DefaultResponse> {
    return (await proxy?.$axios.get(URL.getBookById(bookId))) as DefaultResponse
  }
  return { getBookById }
})
