import { Application } from 'egg';

export default (app: Application) => {
  const { controller, router } = app;

  router.get('/', controller.home.index);
  router.get('/chapter/:chapterId', controller.chapter.getChapterById);
  router.get('/chapter/book/:bookId', controller.chapter.getChapterListByBookId);
};
