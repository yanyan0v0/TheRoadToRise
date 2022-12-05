import { createApp } from 'vue'
import { createPinia } from 'pinia'

import ViewUIPlus from 'view-ui-plus'
import App from '@/App.vue'
import router from '@/router'
import axios from '@/utils/axios'

import 'view-ui-plus/dist/styles/viewuiplus.css'
import '@/assets/main.css'

const app = createApp(App)
app.config.globalProperties.$axios = axios

app.use(createPinia())
app.use(router)
app.use(ViewUIPlus)

app.mount('#app')
