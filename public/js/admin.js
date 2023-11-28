
function timeConverter(UNIX_timestamp){
    var a = new Date(UNIX_timestamp * 1000);
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var year = a.getFullYear();
    var month = months[a.getMonth()];
    var date = a.getDate();
    var hour = a.getHours();
    var min = a.getMinutes();
    var sec = a.getSeconds();
    var time = date + ' ' + month + ' ' + year + ' ' + hour + ':' + min + ':' + sec ;
    return time;
}
let previous_scroll = 0
let listArticle = async () => {
    // window.scrollTo(0, previous_scroll)
    let article_cont = document.getElementById("articles-container")
    article_cont.innerHTML = '';
    let post_meta = await fetch("/post").then((res) => res.json())

    let row = document.createElement("div")
    row.className = "article-row"
    post_meta.forEach((element, i) => {
        if (i !== 0 && i % 2 === 0) {
            article_cont.appendChild(row)
            row = document.createElement("div")
            row.className = "article-row"
        }
        const s = `        
        <a class="article-col" href="article/${element.id}">
            <h2 class="article-cover" style="background-image: url('image/showcase.png');" article_id="${element.id}">
                <div class="article-desc">
                    ${element.title}
                </div>
            </h2>
        </a>`
        let article_col = DOMFromStr(s)

        article_col.addEventListener('click', route)
        row.appendChild(article_col)
    });
}
let indexScroll = (ev) => {
    let index = document.getElementById('article-index')
    let article_cont = document.getElementById("articles-container")
    if (index === null) return;
    let pad_str = window.getComputedStyle(article_cont, null).getPropertyValue('padding-top')
    let pad = parseFloat(pad_str.slice(0, pad_str.length - 2))
    // console.log(document.documentElement.scrollTop, article_cont.offsetTop)

    let val = 0
    if (document.documentElement.scrollTop < article_cont.offsetTop) {
        val = article_cont.offsetTop - document.documentElement.scrollTop + pad
    } else {
        val = pad
    }
    index.style.top = `${val}px`
    let save = document.getElementById('save')
    save.style.top = `${val - 50}px`
}
let saveScroll = (ev) => {

}
let preview = true
let content = ""
let article_id = -1
let loadArticle = async (id) => {
    article_id = id
    let article = await (await fetch(`/post/${id}`)).json()
    let res = article;
    let article_cont = document.getElementById("articles-container")
    window.scroll(5, 0)

    window.onscroll = () => {
        indexScroll()
        saveScroll()
    }
    window.onscroll()
    content = res.content
    let s =         
    `        
    <label class="switch">
        <input type="checkbox">
        <span class="slider"  id="edit-switch"></span>
    </label>
    <button id='save'>Save</button>
    <div id="article-index"></div>
    <div id="article-content">
        <h1 id="article-title">${res.title}</h1>
        <div>views: ${res.views}</div>
        <div>created: ${timeConverter(res.created_time)}, last modified: ${timeConverter(res.modified_time)}</div>
        <br></br>
        <div id="text">
        ${content}
        </div>
    </div>`
    article_cont.innerHTML = s.trim()
    generateIndex()

    let sw = document.getElementById('edit-switch')
    sw.onclick = editArticle
    let save = document.getElementById('save')
    save.onclick = async (ev) => {
        let response = await fetch(`/post/${id}`, {
            method: "PUT",
            body: JSON.stringify({
                content: content
            })
        })
        if (response.status !== 200) {
            console.warn("Cannot Save")
        }
    }

    window.scrollTo(0, article_cont.offsetTop)
}
let covertMarkdown = (content) => {
    var converter = new showdown.Converter()
    let html = converter.makeHtml(content)
    let html_dom = DOMFromStr(html)
    let codes = html_dom.getElementsByTagName('code')
    return html
}
let generateIndex = () => {
    let index = document.getElementById("article-index")
    let article_content = document.getElementById('article-content')
    let title = document.getElementById('article-title')

    index.innerHTML = ''
    let title_clone = document.createElement('a')
    title_clone.innerHTML = title.innerHTML
    title_clone.href = `#article-title`
    index.appendChild(title_clone)
    
    let h3s = article_content.getElementsByTagName('H3')
    for (let h3 of h3s) {
        h3.id = "__article_index_" + h3.innerHTML;
        let a = document.createElement('a')
        a.innerHTML = h3.innerHTML
        a.href = `#${h3.id}`
        index.appendChild(a)
    }
}
let dirty = false
let editArticle = (ev) => {
    ev.stopPropagation()
    preview = !preview
    let text = document.getElementById('text')
    let index = document.getElementById('article-index')
    if (preview) {
        index.style.display = ''
        content = text.firstElementChild.value
        text.innerHTML = covertMarkdown(content)
        generateIndex()
    } else {
        dirty = true
        index.style.display = 'none'
        let input = DOMFromStr('<textarea type="text" id="editor"></textarea>')
        input.value = content
        text.innerHTML = ''
        text.appendChild(input)
    }


}
const base = "/admin"
const route = (event) => {
    // console.log(event.target)
    
    let href = getTargetA(event).getAttribute('href')
    event = event || window.event;
    event.preventDefault();
    window.history.pushState({}, "", base + "/" + href);
    handleLocation()

};

// const routes = {
//     404: "/pages/404.html",
//     "/": "/pages/index.html",
//     "/about": "/pages/about.html",
//     "/lorem": "/pages/lorem.html",
// };

const handleLocation = async () => {
    const path_ = window.location.pathname;
    const path = path_.slice(base.length, path_.length)

    if (path.length === 0) {
        dirty = false
        return await listArticle()
    }
    let match = (/^\/article\/(\d+)$/.exec(path) || [-1,-1])
    console.log(match, path)
    let article_id = match[1]
    let jump_id = window.location.hash
    console.log(jump_id)
    if (article_id > 0) {
        if (jump_id !== "" && dirty) {
            scrollTo(0, document.getElementById(jump_id).offsetTop)
        } else {
            return loadArticle(article_id)
        }
    }
}

window.onpopstate = handleLocation;
window.route = route;

// window.onload = async () => {
//     listArticle()
// }
window.onload = handleLocation();

function getTargetA(ev) {
    return ev.target.tagName == 'H2' ? ev.target.parentElement : ev.target.parentElement.parentElement
}

function DOMFromStr(s) {
    let d = document.createElement("div")
    d.innerHTML = s.trim()
    return d.firstChild;
}