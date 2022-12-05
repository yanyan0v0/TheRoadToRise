import axios from 'axios'
import { Message } from 'view-ui-plus' // 引入提示框

// 设置接口超时时间
axios.defaults.timeout = 60000

// 请求地址，这里是动态赋值的的环境变量
axios.defaults.baseURL = import.meta.env.VITE_HOST

//http request 拦截器
axios.interceptors.request.use(
  (config) => config,
  (error) => Promise.reject(error)
)

//http response 拦截器
axios.interceptors.response.use(
  (response) => {
    if (response.data.code === 0) {
      return response.data
    } else {
      Message.warning(response.data.msg)
    }
    throw response.data
  },
  (error) => {
    const { response = {} } = error
    Message.warning(response.data?.msg || '网络连接异常,请稍后再试!')
    throw response.data
  }
)

export default axios
