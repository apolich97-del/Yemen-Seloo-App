import { CatalogItem } from '../types/seloo';

const DB_NAME = 'yemen_seloo_cache_v1';
const DB_VERSION = 1;
const STORE_CATALOG = 'catalog';
const STORE_PRICES = 'size_prices';

function openCacheDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === 'undefined') {
      reject(new Error('IndexedDB unavailable'));
      return;
    }
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE_CATALOG)) {
        db.createObjectStore(STORE_CATALOG, { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains(STORE_PRICES)) {
        db.createObjectStore(STORE_PRICES, { keyPath: 'goodsId' });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function cacheCatalogItems(items: CatalogItem[]): Promise<void> {
  try {
    const db = await openCacheDb();
    const tx = db.transaction(STORE_CATALOG, 'readwrite');
    const store = tx.objectStore(STORE_CATALOG);
    store.clear();
    for (const item of items) {
      store.put(item);
    }
  } catch {
    // Graceful no-op in restricted browser contexts
  }
}

export async function readCachedCatalogItems(): Promise<CatalogItem[]> {
  try {
    const db = await openCacheDb();
    return await new Promise((resolve) => {
      const tx = db.transaction(STORE_CATALOG, 'readonly');
      const req = tx.objectStore(STORE_CATALOG).getAll();
      req.onsuccess = () => resolve((req.result as CatalogItem[]) || []);
      req.onerror = () => resolve([]);
    });
  } catch {
    return [];
  }
}

export async function cacheSheinSizePrices(
  goodsId: string,
  sizePrices: Record<string, number>
): Promise<void> {
  try {
    const db = await openCacheDb();
    const tx = db.transaction(STORE_PRICES, 'readwrite');
    tx.objectStore(STORE_PRICES).put({
      goodsId,
      sizePrices,
      updatedAt: Date.now(),
    });
  } catch {
    // no-op
  }
}

export async function readCachedSheinSizePrices(
  goodsId: string
): Promise<Record<string, number> | null> {
  try {
    const db = await openCacheDb();
    return await new Promise((resolve) => {
      const tx = db.transaction(STORE_PRICES, 'readonly');
      const req = tx.objectStore(STORE_PRICES).get(goodsId);
      req.onsuccess = () => {
        const res = req.result as { sizePrices?: Record<string, number> } | undefined;
        resolve(res?.sizePrices || null);
      };
      req.onerror = () => resolve(null);
    });
  } catch {
    return null;
  }
}
