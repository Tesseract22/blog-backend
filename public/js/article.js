var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
const route = (event) => {
    // console.log(event.target)
    let href = getTargetA(event).getAttribute('href');
    event = event || window.event;
    event.preventDefault();
    window.history.pushState({}, "", href);
    handleLocation();
};
const handleLocation = (ev) => __awaiter(this, void 0, void 0, function* () {
    const path = window.location.pathname;
    if (path === "/") {
        yield listArticle(false);
        return;
    }
    let article_id = (/^\/article\/(\d+)$/.exec(path) || [-1, -1])[1];
    if (article_id > 0)
        loadArticle(article_id);
});
window.onpopstate = handleLocation;
window.onload = (ev) => {
    handleLocation(null);
};
