import { getCurrentInstance, type ComponentInternalInstance } from 'vue'
import { defineStore } from 'pinia'
import URL from '@/utils/url'
import type { DefaultResponse } from 'env'

export const chapterStore = defineStore('chapter', () => {
  const { proxy } = getCurrentInstance() as ComponentInternalInstance

  async function getChapterListByBookId(bookId: number | string): Promise<DefaultResponse> {
    return (await proxy?.$axios.get(URL.getChapterListByBookId(bookId))) as DefaultResponse
  }

  async function getChapterById(bookId: number | string, chapterId: number | string): Promise<DefaultResponse> {
    return (await proxy?.$axios.get(URL.getChapterById(bookId, chapterId))) as DefaultResponse
  }
  return { getChapterById, getChapterListByBookId }
})
