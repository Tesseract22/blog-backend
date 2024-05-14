/// <reference path="hljs.d.ts"/>
/// <reference path="showdown.d.ts"/>
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
function loadCSS(name) {
    let head = document.getElementsByTagName("head")[0];
    let css = document.createElement("link");
    css.rel = "stylesheet";
    css.type = "text/css";
    css.href = `/css/${name}.css`;
    head.appendChild(css);
}
function load404() {
    let menu = getMenu();
    menu.style.display = 'none';
    let article_cont = document.getElementById("articles-container");
    article_cont.innerHTML = "<b>404 Page Not Found!</b>";
    article_cont.style.justifyContent = "center";
}
function timeConverter(UNIX_timestamp) {
    var a = new Date(UNIX_timestamp * 1000);
    var months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    var year = a.getFullYear();
    var month = months[a.getMonth()];
    var date = a.getDate();
    var hour = a.getHours();
    var min = a.getMinutes();
    var sec = a.getSeconds();
    var time = date + ' ' + month + ' ' + year + ' ' + hour + ':' + min + ':' + sec;
    return time;
}
let listArticle = (admin) => __awaiter(this, void 0, void 0, function* () {
    let article_cont = document.getElementById("articles-container");
    article_cont.style.justifyContent = 'start';
    article_cont.style.flexDirection = 'row';
    article_cont.style.alignItems = 'center';
    article_cont.innerHTML = '';
    let menu = getMenu();
    menu.style.display = 'none';
    let editing_title = false;
    let editing_cover = false;
    let raw = yield fetch("/post");
    // console.log(raw)
    let post_meta = yield raw.json().catch((reason) => console.log(reason));
    let appendArticle = (post) => {
        // console.log(post.published!)
        if (post.published != 1 && !admin) {
            return;
        }
        const s = `        
        <a class="article-col" href="article/${post.id}" article_id="${post.id}">
            <h2 class="article-cover" id="article_${post.id}" published='${post.published}'>
                <div class="article-desc">
                    ${post.title}
                </div>
            </h2>
        </a>`;
        let article_col = DOMFromStr(s);
        if (post.id < 0) {
            article_col.style.opacity = '0';
        }
        else if (admin) {
            (article_col).addEventListener('contextmenu', (ev) => {
                ev.preventDefault();
                menu.style.top = `${ev.pageY}px`;
                menu.style.left = `${ev.pageX}px`;
                menu.style.display = '';
                let old_id = menu.getAttribute('article_id') || -1;
                let new_id = ev.currentTarget.getAttribute('article_id');
                menu.setAttribute('article_id', new_id);
                let orignal_txt = ["Delete", "Edit Title", "Edit Cover", getArticleCover(new_id).getAttribute("published") === "false" ? "Publish" : "Unpublish"];
                if (old_id !== new_id) {
                    for (var i = 0, len = menu.childElementCount; i < len; ++i) {
                        menu.children[i].innerHTML = orignal_txt[i];
                    }
                    editing_cover = false;
                    editing_title = false;
                }
            }, false);
        }
        article_col.addEventListener('click', route);
        article_cont.appendChild(article_col);
        const background_el = article_col.firstElementChild;
        if (post.cover_url) {
            background_el.style.backgroundImage = Url2Css(post.cover_url);
        }
        else {
            background_el.style.background = `crimson`;
        }
    };
    post_meta.forEach(appendArticle);
    if (!admin)
        return;
    // auxiliary "article" for adding new article
    let add = DOMFromStr('<a class="article-col add" id="add">+</a>');
    add.addEventListener('click', (ev) => __awaiter(this, void 0, void 0, function* () {
        ev.preventDefault();
        let response = yield fetch("/post", {
            method: 'POST',
            body: JSON.stringify({
                title: "new title",
                content: "Edit Me",
                author: "cat",
                published: false,
                cover_url: "",
            })
        });
        let id = (yield response.json()).id;
        let response2 = yield fetch(`post/${id}`, {
            method: 'PATCH'
        });
        if (response2.status == 200) {
            let new_meta = yield response2.json();
            let add = article_cont.lastChild;
            appendArticle(new_meta);
            article_cont.append(add);
        }
    }));
    article_cont.appendChild(add);
    getArticlesBg().onclick = (ev) => {
        menu.style.display = 'none';
    };
    // context menu for editing article
    let addMenuItem = (id, callback) => {
        let el = document.getElementById(id);
        el.addEventListener('click', (ev) => __awaiter(this, void 0, void 0, function* () {
            ev.preventDefault();
            ev.stopPropagation();
            let article_id = menu.getAttribute('article_id');
            callback(article_id, el);
        }));
    };
    addMenuItem('delete', (id, target) => __awaiter(this, void 0, void 0, function* () {
        let response = yield fetch(`/post/${id}`, {
            method: 'DELETE',
        });
        if (response.status == 200) {
            article_cont.removeChild(getArticleOut(id));
            menu.style.display = 'none';
        }
    }));
    addMenuItem('edit-title', (id, target) => __awaiter(this, void 0, void 0, function* () {
        if (editing_title)
            return;
        editing_title = true;
        let article_title_el = getArticleTitle(id);
        let inp = document.createElement('input');
        inp.type = 'text';
        inp.className = 'edit-input';
        inp.value = article_title_el.innerText;
        target.innerHTML = '';
        target.appendChild(inp);
        // commit on enter
        inp.onkeydown = (ev2) => __awaiter(this, void 0, void 0, function* () {
            var keyCode = ev2.key;
            if (keyCode == 'Enter') {
                let response = yield fetch(`/post/${id}`, {
                    method: 'PUT',
                    body: JSON.stringify({
                        title: inp.value
                    })
                });
                if (response.status === 200) {
                    article_title_el.innerText = inp.value;
                    target.innerHTML = 'Edit Title';
                    editing_title = false;
                }
            }
        });
    }));
    addMenuItem('edit-cover', (id, target) => __awaiter(this, void 0, void 0, function* () {
        if (editing_cover)
            return;
        editing_cover = true;
        let article_bg_el = getArticleCover(id);
        let inp = document.createElement('input');
        inp.type = 'text';
        inp.className = 'edit-input';
        inp.value = Css2Url(article_bg_el.style.backgroundImage);
        target.innerHTML = '';
        target.appendChild(inp);
        inp.onkeydown = (ev2) => __awaiter(this, void 0, void 0, function* () {
            var keyCode = ev2.key;
            if (keyCode == 'Enter') {
                let response = yield fetch(`/post/${id}`, {
                    method: 'PUT',
                    body: JSON.stringify({
                        cover_url: inp.value
                    })
                });
                if (response.status === 200) {
                    article_bg_el.style.backgroundImage = Url2Css(inp.value);
                    target.innerHTML = 'Edit Cover';
                    editing_cover = false;
                }
            }
        });
    }));
    addMenuItem('edit-publish', (id, target) => __awaiter(this, void 0, void 0, function* () {
        let cover = getArticleCover(id);
        let stat = cover.getAttribute('published') === "true";
        let response = yield fetch(`/post/${id}`, {
            method: 'PUT',
            body: JSON.stringify({
                published: !stat,
            })
        });
        if (response.status == 200) {
            target.innerHTML = stat ? 'Publish' : 'Unpublish';
            cover.setAttribute('published', !stat ? "true" : "false");
        }
    }));
});
let Url2Css = (u) => {
    return `url("${u}")`;
};
let Css2Url = (c) => {
    return c.substring(5, c.length - 2);
};
let indexScroll = (ev) => {
    let index = getArticleIndex();
    let article_cont = getArticlesContainer();
    if (index === null)
        return;
    let pad_str = window.getComputedStyle(article_cont, null).getPropertyValue('padding-top');
    let pad = parseFloat(pad_str.slice(0, pad_str.length - 2));
    if (document.documentElement.scrollTop < article_cont.offsetTop) {
        index.style.top = `${article_cont.offsetTop - document.documentElement.scrollTop + pad}px`;
    }
    else {
        index.style.top = pad_str;
    }
};
// function showdownKatex(a: any)
let convertMarkdown = (content) => {
    var converter = new showdown.Converter({
        extensions: [
            showdownKatex({
                output: "mathml",
            }),
        ],
    });
    console.log("convert markdown");
    let html = converter.makeHtml(content);
    let tmp = document.createElement('div');
    tmp.innerHTML = html.trim();
    let codes = tmp.getElementsByTagName('code');
    return tmp.innerHTML;
};
let generateIndex = () => {
    let index = document.getElementById("article-index");
    let article_content = document.getElementById('article-content');
    let title = document.getElementById('article-title');
    index.innerHTML = '';
    let title_clone = document.createElement('a');
    title_clone.innerHTML = title.innerHTML;
    title_clone.href = `#article-title`;
    index.appendChild(title_clone);
    let h3s = article_content.getElementsByTagName('H3');
    for (let h3 of h3s) {
        h3.id = "__article_index_" + h3.innerHTML;
        let a = document.createElement('a');
        a.innerHTML = h3.innerHTML;
        a.href = `#${h3.id}`;
        a.onclick = (ev) => { ev.preventDefault(); h3.scrollIntoView(); };
        index.appendChild(a);
    }
};
let preview = true;
let article_id = -1;
let dirty = false;
let loadArticle = (id, callback) => __awaiter(this, void 0, void 0, function* () {
    getMenu().style.display = 'none';
    let article = yield (yield fetch(`/post/${id}`)).text();
    let res = JSON.parse(article);
    let article_cont = document.getElementById("articles-container");
    article_cont.style.justifyContent = 'center';
    article_cont.style.flexDirection = 'column';
    article_cont.style.alignItems = 'center';
    window.scroll(5, 0);
    let s = `        
    <div id="article-index"></div>
    <div id="article-content">
        <h1 id="article-title">${res.title}</h1>
        <div>views: ${res.views}</div>
        <div>created: ${timeConverter(res.created_time)}, last modified: ${timeConverter(res.modified_time)}</div>
        <br></br>   
        <div id="text">
        ${convertMarkdown(res.content)}
        </div>
    </div>`;
    article_cont.innerHTML = s.trim();
    hljs.highlightAll();
    generateIndex();
    window.onscroll = () => {
        indexScroll(null);
    };
    indexScroll(null);
    if (callback) {
        callback(res, id);
    }
    window.scrollTo(0, article_cont.offsetTop);
});
let getArticlesBg = () => {
    return document.getElementById("article-background");
};
let getArticleCover = (id) => {
    return document.getElementById(`article_${id}`);
};
let getArticleOut = (id) => {
    return getArticleCover(id).parentElement;
};
let getArticleTitle = (id) => {
    return getArticleCover(id).firstElementChild;
};
let getArticleIndex = () => {
    return document.getElementById('article-index');
};
let getArticlesContainer = () => {
    return document.getElementById("articles-container");
};
let getMenu = () => {
    return document.getElementById('menu');
};
function getTargetA(ev) {
    return ev.target.tagName == 'H2' ? ev.target.parentElement : ev.target.parentElement.parentElement;
}
function DOMFromStr(s) {
    let d = document.createElement("div");
    d.innerHTML = s.trim();
    return d.firstChild;
}
