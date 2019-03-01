import Vue from 'vue'
import Router from 'vue-router'
import Default from '@/components/Default'

Vue.use(Router)

export default new Router({
  routes: [
    {
      path: '/',
      name: 'Default',
      component: Default
    }
  ]
})
