# Ignore warnings for missing classes
-ignorewarnings
-dontwarn **

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Apache Tika - XML Stream Exception handling
-dontwarn javax.xml.stream.**
-dontwarn org.apache.tika.**
-keep class org.apache.tika.** { *; }

# Ignore missing XML Stream classes (not available on Android)
-dontwarn javax.xml.stream.**
-dontnote javax.xml.stream.**
-dontwarn javax.xml.stream.XMLStreamException
-dontnote javax.xml.stream.XMLStreamException
-dontwarn javax.xml.stream.XMLInputFactory
-dontwarn javax.xml.stream.XMLOutputFactory
-dontwarn javax.xml.stream.XMLStreamReader
-dontwarn javax.xml.stream.XMLStreamWriter

# Keep XMLReaderUtils and related classes
-keep class org.apache.tika.utils.XMLReaderUtils { *; }
-keep class org.apache.tika.utils.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep annotation default values
-keepattributes AnnotationDefault

# Keep line numbers for stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

