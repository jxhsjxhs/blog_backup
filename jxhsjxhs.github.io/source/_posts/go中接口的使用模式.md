---
title: go中接口的使用模式
date: 2023-05-16 09:23:43
tags:
index_img: /img/newimg/2f2580e785142bd448594fd8a0f95b5.png
banner_img: /img/newimg/2f2580e785142bd448594fd8a0f95b5.png
---


接口本质上是一种抽象，它的功能是解耦，是方法或者功能的解耦。但是不要为了解耦而解耦，会脱裤子放屁的感觉。

比如 我现在有一个函数 是对两个int64 类型相加，本来可以这么实现

```
func Add(a int64,b int64) int64{
    return a+b
}
```
但是我们如果非要解耦，使用接口的方式来实现，那就变成了这样
```
type Adder interface{
    Add(int64 int64)int64
}

func Add(adder Adder, a int64, b int64) int64 {
     return adder.Add(a, b)
}
```
这就会产生一种“过设计”的味道了。
虽然接口的确可以实现解耦，但它也会引入“抽象”的副作用，或者说接口这种抽象也不是免费的，是有成本的，除了会造成运行效率的下降之外，也会影响代码的可读性。

那么实际在项目中`接口的使用方式主要是为了连接方法跟结构体。作为程序的骨架`
用专业的角度来说，就是为了结构搭建与耦合设计的关键。

目前一般有两种接口的组合方式，一种为垂直组合，一种为水平组合。
![组合方式](/img/newimg/184abd340a504697bf4f0a06ddfb863.jpg) 
首先讲垂直组合。
第一种：通过嵌入接口构建接口
通过在接口定义中嵌入其他接口类型，实现接口行为聚合，组成大接口。这种方式在标准库中非常常见，也是 Go 接口类型定义的惯例，我们在前面的讲解中也不止一次提及。比如这个 ReadWriter 接口类型就采用了这种类型嵌入方式：
```
// $GOROOT/src/io/io.go
type ReadWriter interface {
    Reader
    Writer
}
```
这里可以看到 io库中的`ReadWriter`方法实际就是`Reader`跟`Writer`的累加。

第二种：通过嵌入接口构建结构体类型
```
type MyReader struct {
  io.Reader // underlying reader
  N int64   // max bytes remaining
}
```
在`MyReader`结构体中嵌入 `io.Reader`接口，可以快速满足一个接口的结构体类型，来满足单元测试的需要。

第三种：通过嵌入结构体类型构建新结构体类型
可以通过嵌入结构体类型后，内部结构体的方法就可以被外部结构体的实例化使用，可以认为是方法的`继承`
```
//首先我们创建 一个Fly的方法，先不用关心他的实现，我们就认为我们实现了fly这个方法
type Fly interface {
	fly()
}

//然后我们创建一个Brid结构体，创建的时候我们嵌套这个接口，可以理解为让这个结构体的拥有这个方法。这样就把接口Fly的方法给到了Brid。它的实例化也有fly()。
type Brid struct {
	Swin string
	Fly
}

//我们初始化Brid发现，他已经拥有fly这个方法，可以理解为它继承到了结构体中的接口方法
func main() {
	var brid Brid
	brid.fly()
}


```


接下来是水平组合。

### 创建模式

```

// $GOROOT/src/sync/cond.go
type Cond struct {
    ... ...
    L Locker
}

func NewCond(l Locker) *Cond {
    return &Cond{L: l}
}

// $GOROOT/src/log/log.go
type Logger struct {
    mu     sync.Mutex 
    prefix string     
    flag   int        
    out    io.Writer  
    buf    []byte    
}

func New(out io.Writer, prefix string, flag int) *Logger {
    return &Logger{out: out, prefix: prefix, flag: flag}
}

// $GOROOT/src/log/log.go
type Writer struct {
    err error
    buf []byte
    n   int
    wr  io.Writer
}

func NewWriterSize(w io.Writer, size int) *Writer {
    // Is it already a Writer?
    b, ok := w.(*Writer)
    if ok && len(b.buf) >= size {
        return b
    }
    if size <= 0 {
        size = defaultBufSize
    }
    return &Writer{
        buf: make([]byte, size),
        wr:  w,
    }
}
```
可以看到。创建模式在 sync、log、bufio 包中都有应用。
这种叫做创建模式的水平组合方法，实际是吧接口当做关节在使用。可以简单理解为 ` 接受接口 返回结构体`，在这个函数中，我们就对这个结构体进行了创建 或者重构。
大多数包含接口类型字段的结构体的实例化，都可以使用创建模式实现。这个模式比较容易理解。


### 包装器模式

func YourWrapperFunc(param YourInterfaceType) YourInterfaceType
通过这个函数，我们可以实现对输入参数的类型的包装，并在不改变被包装类型（输入参数类型）的定义的情况下，返回具备新功能特性的、实现相同接口类型的新类型。这种接口应用模式我们叫它包装器模式，也叫装饰器模式。包装器多用于对输入数据的过滤、变换等操作。 （ps 如果不能理解，想象一下一个人 吃的啥拉的也是啥）


以下是案例，是一个标准库的Reader库的包装器
```

// $GOROOT/src/io/io.go
func LimitReader(r Reader, n int64) Reader { return &LimitedReader{r, n} }

type LimitedReader struct {
    R Reader // underlying reader
    N int64  // max bytes remaining
}

func (l *LimitedReader) Read(p []byte) (n int, err error) {
    // ... ...
}
```
通过LimitReader 函数的包装后，我们得到了一个具有新功能特性的 io.Reader 接口的实现类型，也就是 LimitedReader。这个新类型在 Reader 的语义基础上实现了对读取字节个数的限制。
可以看看LimitReader的使用示例
```
func main() {
    r := strings.NewReader("hello, gopher!\n")
    lr := io.LimitReader(r, 4)
    if _, err := io.Copy(os.Stdout, lr); err != nil {
        log.Fatal(err)
    }
}
```
这个函数只读取4个字符，最后输出为 `hell`。

### 适配器模式

适配器模式的核心是适配器函数类型（Adapter Function Type）。适配器函数类型是一个辅助水平组合实现的“工具”类型。这里我要再强调一下，它是一个类型。它可以将一个满足特定函数签名的普通函数，显式转换成自身类型的实例，转换后的实例同时也是某个接口类型的实现者。

```

// $GOROOT/src/net/http/server.go
type Handler interface {
    ServeHTTP(ResponseWriter, *Request)
}

type HandlerFunc func(ResponseWriter, *Request)

func (f HandlerFunc) ServeHTTP(w ResponseWriter, r *Request) {
    f(w, r)
}

func greetings(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Welcome!")
}

func main() {
    http.ListenAndServe(":8080", http.HandlerFunc(greetings))
}
```

这是一个http请求经常这么操作的，
实际`http.ListenAndServe`函数的参数是一个`http.HandlerFunc`函数，这个函数所需的参数 以及返回值是`ResponseWriter, *Request`，如果我们创建一个函数返回值以及参数与这个相同的情况下。
定义一个 类型为`ServeHTTP(w ResponseWriter, r *Request)`的函数类型`HandlerFunc`， 使用`http.HandlerFunc(greetings)`这种方式进行强制类型转换。

他的作用就完成将一个普通函数，显示转换为自身类型的实例。转换以后这个实例并且还是这个接口的实现。


### 中间件模式

中间件就是包装模式和适配器模式结合的产物。

```

func validateAuth(s string) error {
    if s != "123456" {
        return fmt.Errorf("%s", "bad auth token")
    }
    return nil
}

func greetings(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Welcome!")
}

func logHandler(h http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        t := time.Now()
        log.Printf("[%s] %q %v\n", r.Method, r.URL.String(), t)
        h.ServeHTTP(w, r)
    })
}

func authHandler(h http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        err := validateAuth(r.Header.Get("auth"))
        if err != nil {
            http.Error(w, "bad auth param", http.StatusUnauthorized)
            return
        }
        h.ServeHTTP(w, r)
    })

}

func main() {
    http.ListenAndServe(":8080", logHandler(authHandler(http.HandlerFunc(greetings))))
}
```
这是一个在go http里面经常用到的模式，大家常称为中间件模式，方法中的`validateAuth`,`logHandler`,其实都是接受参数以及返回值一致的包装函数。所以实际这句`logHandler(authHandler(http.HandlerFunc(greetings)))`的处理逻辑如下：
1、通过`http.HandlerFunc`函数将`greetings`这个普通函数转化为 `ServeHTTP`能接受的函数
2、通过 `authHandler`函数包装`http.HandlerFunc(greetings))`,由于`authHandler`函数吃下去的跟吐出来的是一样的。所以也能被 `http.ListenAndServe`函数使用。(如果不能理解，可以想想人体蜈蚣.......yue了。)
3、同理2.

可以看看最终效果,可以看到 我们这个`greetings`函数就有了 日志以及认证模块。这个模式在go web中经常用到。
```

$curl http://localhost:8080
bad auth param

$curl -H "auth:123456" localhost:8080/ 
Welcome!
```
