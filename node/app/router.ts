import { Application } from 'egg';

export default (app: Application) => {
  const { controller, router } = app;

  router.get('/', controller.home.index);
  router.get('/book/:bookId', controller.book.getBookById);
  router.get('/author/:bookId', controller.author.getAuthorByBookId);
  router.get('/book/:bookId/chapter', controller.chapter.getChapterListByBookId);
  router.get('/book/:bookId/chapter/:chapterId', controller.chapter.getChapterById);
};
