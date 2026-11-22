import { createRouter, createWebHistory } from 'vue-router'
import ConsentView from './views/ConsentView.vue'
import LoginView from './views/LoginView.vue'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/login' },
    { path: '/login', component: LoginView },
    { path: '/consent', component: ConsentView },
  ],
})
