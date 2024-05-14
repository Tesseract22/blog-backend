var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
/// <reference path="common.ts"/>
let editor_scroll = 0;
let view_scroll = 0;
let editArticle = (ev) => {
    ev.stopPropagation();
    preview = !preview;
    let text = document.getElementById('text');
    let index = document.getElementById('article-index');
    if (preview) {
        let editor = document.getElementById('editor');
        if (editor)
            editor_scroll = editor.scrollTop;
        index.style.display = '';
        content = text.firstElementChild.value;
        text.innerHTML = convertMarkdown(content);
        hljs.highlightAll();
        generateIndex();
        scrollTo(0, view_scroll);
    }
    else {
        view_scroll = document.body.scrollTop;
        dirty = true;
        document.getElementById('save').innerText = 'Save';
        index.style.display = 'none';
        let input = DOMFromStr('<textarea type="text" id="editor"></textarea>');
        input.value = content;
        text.innerHTML = '';
        text.appendChild(input);
        input.scrollBy(0, editor_scroll);
    }
};
const base = "/admin";
const route = (event) => {
    let href = getTargetA(event).getAttribute('href');
    event = event || window.event;
    event.preventDefault();
    window.history.pushState({}, "", base + "/" + href);
    handleLocation();
};
// const routes = {
//     404: "/pages/404.html",
//     "/": "/pages/index.html",
//     "/about": "/pages/about.html",
//     "/lorem": "/pages/lorem.html",
// };
let content = "";
const handleLocation = () => __awaiter(this, void 0, void 0, function* () {
    console.log("handle location");
    if (window.location.pathname.slice(-1) === "/") {
        window.location.pathname = window.location.pathname.slice(0, -1);
        return;
    }
    const path_ = window.location.pathname;
    const path = path_.slice(base.length);
    const paths = path.split('/').slice(1);
    console.log(path, paths);
    if (path.length === 0) {
        window.location.pathname += "/article";
        return;
    }
    if (paths.length === 1 && paths[0] == "article") {
        dirty = false;
        return yield listArticle(true);
    }
    if (paths.length === 2 && paths[0] === "article" && parseInt(paths[1]) >= 0) {
        let article_id = parseInt(paths[1]);
        return loadArticle(article_id, (res, id) => {
            content = res.content;
            let article_cont = getArticlesContainer();
            let switch_s = `        
            <label class="switch">
                <input type="checkbox">
                <span class="slider"  id="edit-switch"></span>
            </label>`;
            let save_s = `<button id='save'>Save</button>`;
            article_cont.appendChild(DOMFromStr(switch_s));
            article_cont.appendChild(DOMFromStr(save_s));
            let sw = document.getElementById('edit-switch');
            sw.onclick = editArticle;
            let save = document.getElementById('save');
            save.onclick = (ev) => __awaiter(this, void 0, void 0, function* () {
                content = document.getElementById('editor').value;
                let response = yield fetch(`/post/${id}`, {
                    method: "PUT",
                    body: JSON.stringify({
                        content: content
                    })
                });
                if (response.status !== 200) {
                    console.warn("Cannot Save");
                }
                else {
                    save.innerText = "Saved!";
                }
            });
        });
    }
    else if (paths.length === 2 && paths[0] === "image" && parseInt(paths[1]) >= 0) {
        let article_id = parseInt(paths[1]);
        return listImage(article_id);
    }
    else {
        load404();
    }
});
function listImage(id) {
    return __awaiter(this, void 0, void 0, function* () {
        loadCSS("image_dir");
        let images = yield (yield fetch(`/image/${id}`)).json();
        console.log(images);
        let menu = getMenu();
        menu.style.display = 'none';
        let article_cont = document.getElementById("articles-container");
        let copied_show = document.createElement("b");
        copied_show.className = "image-dir";
        // copied_show.id = "copied"
        article_cont.appendChild(copied_show);
        let image_list = document.createElement("div");
        image_list.className = "image-dir";
        image_list.id = "image-dir";
        image_list.ondragenter = () => {
            image_list.style.backgroundColor = "darkseagreen";
        };
        image_list.ondragover = (ev) => {
            ev.preventDefault();
            image_list.style.backgroundColor = "darkseagreen";
        };
        image_list.ondragleave = (ev) => {
            image_list.style.backgroundColor = "";
        };
        let appendImg = (img) => {
            let img_div = document.createElement("a");
            let img_text = document.createElement("div");
            img_text.innerText = img;
            img_text.className = "image-text";
            img_div.appendChild(img_text);
            img_div.href = `/image/${id}/${img}`;
            img_div.className = "image-dir-item";
            let delete_btn = document.createElement("button");
            delete_btn.className = "image-delete-btn";
            delete_btn.onclick = (ev) => {
                ev.preventDefault();
                ev.stopPropagation();
                let btn = ev.target;
                let item_div = btn.parentElement;
                fetch(`/image/${id}?path=${item_div.getAttribute("href")}`, {
                    method: "DELETE",
                }).then((res) => {
                    var _a;
                    if (res.status === 200) {
                        (_a = item_div.parentElement) === null || _a === void 0 ? void 0 : _a.removeChild(item_div);
                    }
                }).catch((err) => {
                    alert(`Failed to delete file: ${ev}`);
                });
            };
            let copy_btn = document.createElement("button");
            copy_btn.className = "image-delete-btn";
            copy_btn.onclick = (ev) => {
                ev.preventDefault();
                ev.stopPropagation();
                let btn = ev.target;
                let item_div = btn.parentElement;
                let href = item_div.getAttribute("href");
                navigator.clipboard.writeText(href).then(() => {
                    copied_show.innerText = `"${href}" copied!`;
                });
            };
            copy_btn.style.backgroundColor = "blue";
            img_div.appendChild(delete_btn);
            img_div.appendChild(copy_btn);
            image_list.append(img_div);
        };
        image_list.ondrop = (ev) => {
            var _a, _b;
            ev.preventDefault();
            image_list.style.backgroundColor = "";
            console.log((_a = ev.dataTransfer) === null || _a === void 0 ? void 0 : _a.files);
            let file = (_b = ev.dataTransfer) === null || _b === void 0 ? void 0 : _b.files[0];
            let formData = new FormData();
            formData.append(file.name || "image.jpg", file);
            fetch(`/image/${id}`, {
                method: "POST",
                body: formData,
            }).then((res) => {
                console.log("upload status:", res.status);
                if (res.status === 200) {
                    appendImg(file.name);
                }
            }).catch((err) => {
                alert(`Failed to upload file '${file.name}': ${err}`);
            });
        };
        images.forEach(appendImg);
        article_cont.appendChild(image_list);
    });
}
window.onpopstate = handleLocation;
window.onload = () => handleLocation();
