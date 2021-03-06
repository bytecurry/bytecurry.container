module bytecurry.container.map;

import std.typecons : Tuple;
import std.range : ForwardRange;

alias MapEntry(K, V) = Tuple!(K, "key", V, "value");

/**
 * Interface for a Map. That is a mapping from keys to values.
 */
interface Map(K, V)
{

    /**
     * A single entry of the Map.
     * It contains a `key` and a `value`.
     */
    alias Entry = MapEntry!(K, V);

    /**
     * Check if the map is empty.
     */
    bool empty() @property;

    /**
     * Clear all elements from the Map
     */
    void clear();

    /**
     * Get the value for a key.
     */
    V opIndex(K key);

    /**
     * Set the value for a key.
     */
    void opIndexAssign(V value, K key);

    /**
     * Insert a Key-Value pair into the Map.
     * If a value already exists for the key, replace it.
     */
    void insert(Entry entry);

    /// ditto
    final void insert(Tuple!(K, V) entry)
    {
        opIndexAssign(entry[1], entry[0]);
    }

    /// ditto
    alias put = insert;

    /**
     * Get a value by key, or a defalt if the value is missing.
     */
    V get(K key, lazy inout(V) defaultVal);

    /**
     * Remove the key (and its value) from the map.
     *
     * Returns: true if something was removed, or false if the key isn't in the map.
     */
    bool remove(K key);

    /**
     * Check if the Map contains a value for a key.
     */
    bool contains(K key) const;

    final bool opBinaryRight(string op: "in")(K key)
    {
        return contains(key);
    }

    /**
     * Returns: A forward range that iterates over the keys of the Map.
     */
    ForwardRange!K byKey() @property;

    /**
     * Returns: A forward range that iterates over the values of the Map.
     */
    ForwardRange!V byValue() @property;

    /**
     * Returns: A forward range that iterates over the Map entries as instances of `Entry`.
     */
    ForwardRange!Entry byKeyValue() @property;

    /// ditto
    alias byPair = byKeyValue;

    /**
     * Loop over the keys and values of the Map. This is may be more efficient than
     * iterating over `byKeyValue`.
     */
    int opApply(int delegate(K key, ref V value) dg);

    Map dup() @property;
}

/**
 * A Map that is implemented using an Associative Array.
 */
class AAMap(K, V) : Map!(K, V)
{
    this() pure {}
    this(V[K] data)
    {
        aa = data;
    }

    this(Entry[] entries...) pure
    {
        foreach (entry; entries)
        {
            aa[entry.key] = entry.value;
        }
    }

    bool empty() const @property
    {
        return aa.length == 0;
    }

    void clear()
    {
        aa.clear();
    }

    V opIndex(K key)
    {
        return aa[key];
    }

    inout(V) opIndex(const(K) key) inout
    {
        return aa[key];
    }

    void opIndexAssign(V value, K key)
    {
        aa[key] = value;
    }

    void insert(Entry entry)
    {
        aa[entry.key] = entry.value;
    }

    inout(V)* getPtr(K key) inout
    {
        return key in aa;
    }

    V get(K key, lazy inout(V) defVal)
    {
        return aa.get(key, defVal);
    }

    inout(V) get(K key, lazy inout(V) defaultVal) inout
    {
        return aa.get(key, defaultVal);
    }

    bool remove(K key)
    {
        return aa.remove(key);
    }

    bool contains(K key) const
    {
        return (key in aa) !is null;
    }

    import std.range : inputRangeObject;

    ForwardRange!K byKey() @property
    {
        return inputRangeObject(aa.byKey);
    }

    ForwardRange!V byValue() @property
    {
        return inputRangeObject(aa.byValue);
    }

    ForwardRange!Entry byKeyValue() @property
    {
        import std.algorithm : map;
        return inputRangeObject(aa.byKeyValue().map!(function (obj) {
                    return Entry(obj.key, obj.value);
                }));
    }

    int opApply(int delegate(K key, ref V value) dg)
    {
        int ret = 0;
        foreach (K key, ref V value; aa)
        {
            ret = dg(key, value);
            if (ret) return ret;
        }
        return ret;
    }

    override bool opEquals(Object other)
    {
        if (this is other) return true;
        auto otherMap = cast(AAMap) other;
        return otherMap && otherMap.aa == aa;
    }

    AAMap dup() @property
    {
        return new AAMap(aa.dup);
    }

    private V[K] aa;
}

///
unittest
{
    auto map = new AAMap!(string, int)();
    assert(map.empty);
    map["a"] = 5;
    assert(map["a"] == 5);
    assert(map.contains("a"));
    assert("a" in map);
    assert(map.get("a", 0) == 5);
    assert(!map.empty);

    map.remove("a");
    assert(map.empty);
    assert(!map.contains("a"));
    assert("a" !in map);

    map["a"] = 1;
    map["b"] = 2;
    map["c"] = 3;

    import std.algorithm : sort, equal;
    import std.array : array;
    assert(equal(map.byKey().array.sort(), ["a", "b", "c"]));
    assert(equal(map.byValue().array.sort(), [1,2,3]));

    auto map2 = new AAMap!(string, int)();

    foreach (key, value; map)
    {
        map2[key] = value;
    }

    assert(map2 == map);
    map2.clear();
    foreach(entry; map.byKeyValue())
    {
        map2[entry.key] = entry.value;
    }
    assert(map2 == map);

    map2 = map.dup;
    assert(map2 == map);
    assert(map2 !is map);

    map.clear();
    assert(map.empty);

    map.insert(mapEntry("b", 4));
    assert(map["b"] == 4);
    map.insert(mapEntry("b", 1));
    assert(map["b"] == 1);
}

/**
 * Convenience function to create a MapEntry.
 */
MapEntry!(K, V) mapEntry(K, V)(K key, V value) pure @nogc nothrow
{
    return MapEntry!(K, V)(key, value);
}
