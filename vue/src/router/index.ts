import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '@/views/Home.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView,
    },
    {
      path: '/book/:bookId',
      name: 'book',
      component: () => import('@/views/Book.vue'),
    },
    {
      path: '/book/:bookId/chapter/:chapterId',
      name: 'chapter',
      component: () => import('@/views/Chapter.vue'),
    },
  ],
})

export default router
