import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '@/views/Home.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView,
      meta: {
        title: '首页',
      },
    },
    {
      path: '/book/:bookId',
      name: 'book',
      component: () => import('@/views/Book.vue'),
    },
    {
      path: '/book/:bookId/chapter/:chapterId',
      name: 'chapter',
      meta: {
        hideHeader: true,
      },
      component: () => import('@/views/Chapter.vue'),
    },
    {
      path: '/author',
      name: 'author',
      component: () => import('@/views/Author.vue'),
      meta: {
        title: '作家专区',
      },
      children: [
        {
          path: '/author/book',
          name: 'authorBook',
          component: () => import('@/components/BookEdit.vue'),
        },
      ],
    },
  ],
})

export default router
