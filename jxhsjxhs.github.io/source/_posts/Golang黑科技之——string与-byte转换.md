---
title: 'Golang黑科技之——string与[]byte转换'
date: 2021-01-07 06:39:44
tags: golang
---


我们知道，相对于C语言，golang是类型安全的语言。但是安全的代价就是性能的妥协。
下面我们通过Golang中的“黑科技”来一窥Golang不想让我们看到的“秘密”——string的底层数据。
通过reflect包，我们可以知道，在Golang底层，string和slice其实都是struct：

```
type SliceHeader struct {
	Data uintptr
	Len  int
	Cap  int
}
type StringHeader struct {
	Data uintptr
	Len  int
}
```

其中Data是一个指针，指向实际的数据地址，Len表示数据长度。
但是，在string和[]byte转换过程中，Golang究竟悄悄帮我们做了什么，来达到安全的目的？
在Golang语言规范里面，string数据是禁止修改的，试图通过&s[0], &b[0]取得string和slice数据指针地址也是不能通过编译的。
下面，我们就通过Golang的“黑科技”来一窥Golang背后的“秘密”。

```
//return GoString's buffer slice(enable modify string)
func StringBytes(s string) Bytes {
	var bh reflect.SliceHeader
	sh := (*reflect.StringHeader)(unsafe.Pointer(&s))
	bh.Data, bh.Len, bh.Cap = sh.Data, sh.Len, sh.Len
	return *(*Bytes)(unsafe.Pointer(&bh))
}

// convert b to string without copy
func BytesString(b []byte) String {
	return *(*String)(unsafe.Pointer(&b))
}

// returns &s[0], which is not allowed in go
func StringPointer(s string) unsafe.Pointer {
	p := (*reflect.StringHeader)(unsafe.Pointer(&s))
	return unsafe.Pointer(p.Data)
}

// returns &b[0], which is not allowed in go
func BytesPointer(b []byte) unsafe.Pointer {
	p := (*reflect.SliceHeader)(unsafe.Pointer(&b))
	return unsafe.Pointer(p.Data)
}
```

以上4个函数的神奇之处在于，通过unsafe.Pointer和reflect.XXXHeader取到了数据首地址，并实现了string和[]byte的直接转换（这些操作在语言层面是禁止的）。
下面我们就通过这几个“黑科技”来测试一下语言底层的秘密：

```
func TestPointer(t *testing.T) {
	s := []string{
		"",
		"",
		"hello",
		"hello",
		fmt.Sprintf(""),
		fmt.Sprintf(""),
		fmt.Sprintf("hello"),
		fmt.Sprintf("hello"),
	}
	fmt.Println("String to bytes:")
	for i, v := range s {
		b := unsafe.StringBytes(v)
		b2 := []byte(v)
		if b.Writeable() {
			b[0] = 'x'
		}
		fmt.Printf("%d\ts=%5s\tptr(v)=%-12v\tptr(StringBytes(v)=%-12v\tptr([]byte(v)=%-12v\n",
			i, v, unsafe.StringPointer(v), b.Pointer(), unsafe.BytesPointer(b2))
	}

	b := [][]byte{
		[]byte{},
		[]byte{'h', 'e', 'l', 'l', 'o'},
	}
	fmt.Println("Bytes to string:")
	for i, v := range b {
		s1 := unsafe.BytesString(v)
		s2 := string(v)
		fmt.Printf("%d\ts=%5s\tptr(v)=%-12v\tptr(StringBytes(v)=%-12v\tptr(string(v)=%-12v\n",
			i, s1, unsafe.BytesPointer(v), s1.Pointer(), unsafe.StringPointer(s2))
	}

}

const N = 3000000

func Benchmark_Normal(b *testing.B) {
	for i := 1; i < N; i++ {
		s := fmt.Sprintf("12345678901234567890123456789012345678901234567890")
		bb := []byte(s)
		bb[0] = 'x'
		s = string(bb)
		s = s
	}
}
func Benchmark_Direct(b *testing.B) {
	for i := 1; i < N; i++ {
		s := fmt.Sprintf("12345678901234567890123456789012345678901234567890")
		bb := unsafe.StringBytes(s)
		bb[0] = 'x'
		s = s
	}
}

//test result
//String to bytes:
//0	s=     	ptr(v)=0x51bd70    	ptr(StringBytes(v)=0x51bd70    	ptr([]byte(v)=0xc042021c58
//1	s=     	ptr(v)=0x51bd70    	ptr(StringBytes(v)=0x51bd70    	ptr([]byte(v)=0xc042021c58
//2	s=hello	ptr(v)=0x51c2fa    	ptr(StringBytes(v)=0x51c2fa    	ptr([]byte(v)=0xc042021c58
//3	s=hello	ptr(v)=0x51c2fa    	ptr(StringBytes(v)=0x51c2fa    	ptr([]byte(v)=0xc042021c58
//4	s=     	ptr(v)=<nil>       	ptr(StringBytes(v)=<nil>       	ptr([]byte(v)=0xc042021c58
//5	s=     	ptr(v)=<nil>       	ptr(StringBytes(v)=<nil>       	ptr([]byte(v)=0xc042021c58
//6	s=xello	ptr(v)=0xc0420444b5	ptr(StringBytes(v)=0xc0420444b5	ptr([]byte(v)=0xc042021c58
//7	s=xello	ptr(v)=0xc0420444ba	ptr(StringBytes(v)=0xc0420444ba	ptr([]byte(v)=0xc042021c58
//Bytes to string:
//0	s=     	ptr(v)=0x5c38b8    	ptr(StringBytes(v)=0x5c38b8    	ptr(string(v)=<nil>
//1	s=hello	ptr(v)=0xc0420445e0	ptr(StringBytes(v)=0xc0420445e0	ptr(string(v)=0xc042021c38
//Benchmark_Normal-4   	1000000000	         0.87 ns/op
//Benchmark_Direct-4   	2000000000	         0.24 ns/op
```

结论如下：

1.string常量会在编译期分配到只读段，对应数据地址不可写入，并且相同的string常量不会重复存储。
2.fmt.Sprintf生成的字符串分配在堆上，对应数据地址可修改。
3.常量空字符串有数据地址，动态生成的字符串没有设置数据地址
4.Golang string和[]byte转换,会将数据复制到堆上，返回数据指向复制的数据
5.动态生成的字符串，即使内容一样，数据也是在不同的空间
6.只有动态生成的string，数据可以被黑科技修改
8.string和[]byte通过复制转换，性能损失接近4倍