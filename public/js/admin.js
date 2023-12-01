
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
    article_cont.style.justifyContent = 'start'
    article_cont.innerHTML = ''
    let menu = document.getElementById('menu')
    menu.style.display = 'none'


    let post_meta = await fetch("/post").then((res) => res.json())
    console.log(post_meta)
    let appendArticle = (element) => {
        console.log(element.cover_url)
        const s = `        
        <a class="article-col" href="article/${element.id}">
            <h2 class="article-cover" article_id="${element.id}" id="article_${element.id}">
                <div class="article-desc">
                    ${element.title}
                </div>
            </h2>
        </a>`
        let article_col = DOMFromStr(s)
        if (element.id < 0) {
            article_col.style.opacity  = '0'
        } else {
            article_col.addEventListener('contextmenu', (ev) => {
                ev.preventDefault()
                menu.style.top = `${ev.pageY}px`
                menu.style.left = `${ev.pageX}px`
                menu.style.display = ''
                menu.setAttribute('article_id', ev.target.getAttribute('article_id'))
            }, false);
        }
        article_col.addEventListener('click', route)
        article_cont.appendChild(article_col)
        if (element.cover_url) {
            document.getElementById(`article_${element.id}`).style.backgroundImage = element.cover_url
        } else {
            document.getElementById(`article_${element.id}`).style.background = `crimson`
        }
    }
    post_meta.forEach(appendArticle);

    let add = DOMFromStr('<a class="article-col add" id="add">+</a>')
    add.addEventListener('click', async (ev) => {
        ev.preventDefault()
        console.log("insert")
        let response = await fetch("/post", {
            method: 'POST',
            body: JSON.stringify({
                title: "new title",
                content: "Edit Me",
                author: "cat",
                published: 0,
                cover_url: "",
            })
        })
        let id = (await response.json()).id
        let response2 = await fetch(`post/${id}`, {
            method: 'PATCH'
        })
        if (response2.status == 200) {
            let new_meta = await response2.json()
            console.log(new_meta)
            let add = article_cont.lastChild
            appendArticle(new_meta)
            article_cont.append(add)
        }
    })
    article_cont.appendChild(add)

    article_cont.onclick = () => menu.style.display = 'none'
    document.getElementById('delete').addEventListener('click', async (ev) => {
        ev.preventDefault()
        ev.stopPropagation()
        let id = ev.target.parentElement.getAttribute('article_id')
        let response = await fetch(`/post/${id}`, {
            method: 'DELETE',
        })
        if (response.status == 200) {
            console.log("deleteing")
            article_cont.removeChild(document.getElementById(`article_${id}`).parentElement)
            // listArticle()
        }
        menu.style.display = 'none'
    })
    document.getElementById('edit-title').addEventListener('click', async (ev) => {
        ev.preventDefault()
        ev.stopPropagation()
        let target = ev.target.tagName === 'INPUT' ? ev.target.parentElement.parentElement : ev.target.parentElement
        let id = target.getAttribute('article_id')
        let article = document.getElementById(`article_${id}`).firstElementChild
        
        let inp = document.createElement('input')
        inp.type = 'text'
        inp.className = 'edit-input'
        inp.value = article.innerText
        ev.target.innerHTML = ''
        ev.target.appendChild(inp)

        inp.onkeydown = async (ev2) => {
            var keyCode = ev2.key
            if (keyCode == 'Enter'){
                let response = await fetch(`/post/${id}`, {
                    method: 'PUT',
                    body: JSON.stringify({
                        title: inp.value
                    })
                })
                if (response.status === 200) {
                    article.innerHTML = inp.value
                    ev.target.innerHTML = 'Edit Title'
                }

            }
        }
    })
    document.getElementById('edit-cover').addEventListener('click', async (ev) => {
        ev.preventDefault()
        ev.stopPropagation()
        let target = ev.target.tagName === 'INPUT' ? ev.target.parentElement.parentElement : ev.target.parentElement
        let id = target.getAttribute('article_id')
        console.log(id, target)
        let article = document.getElementById(`article_${id}`)
        
        let inp = document.createElement('input')
        inp.type = 'text'
        inp.className = 'edit-input'
        inp.value = article.style.backgroundImage
        ev.target.innerHTML = ''
        ev.target.appendChild(inp)

        inp.onkeydown = async (ev2) => {
            var keyCode = ev2.key
            if (keyCode == 'Enter'){
                let response = await fetch(`/post/${id}`, {
                    method: 'PUT',
                    body: JSON.stringify({
                        cover_url: inp.value
                    })
                })
                if (response.status === 200) {
                    article.style.backgroundImage = inp.value
                    ev.target.innerHTML = 'Edit Cover'
                }
            }
        }
    })
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
    document.getElementById('menu').style.display = 'none'
    let article = await (await fetch(`/post/${id}`)).text()
    console.log(article)
    article = JSON.parse(article)
    let res = article;
    let article_cont = document.getElementById("articles-container")
    article_cont.style.justifyContent = 'center'
    article_cont.style.flexDirection = 'column'
    article_cont.style.alignItems = 'center'
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
        ${convertMarkdown(content)}
        </div>
    </div>`

    article_cont.innerHTML = s.trim()
    hljs.highlightAll()
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
        } else {
            save.innerText = "Saved!"
        }
    }

    window.scrollTo(0, article_cont.offsetTop)
}
let convertMarkdown = (content) => {
    var converter = new showdown.Converter()
    let html = converter.makeHtml(content)
    let tmp = document.createElement('div')
    tmp.innerHTML = html.trim()
    let codes = tmp.getElementsByTagName('code')
    console.log(codes)
    return tmp.innerHTML
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
        text.innerHTML = convertMarkdown(content)
        hljs.highlightAll()
        generateIndex()
    } else {
        dirty = true
        document.getElementById('save').innerText = 'Save'
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

