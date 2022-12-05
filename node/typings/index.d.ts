import 'egg';

declare module 'egg' {
  declare interface Chapter {
    id?: number;
    name?: string;
    wordCount?: number;
    bookId?: number;
    file?: string;
    time?: string;
  }
  declare interface Book {
    id?: number;
    name?: string;
    type?: string[];
    state?: number;
    wordCount?: number;
    reader?: number;
    authorId?: number;
    description?: string;
  }
}
